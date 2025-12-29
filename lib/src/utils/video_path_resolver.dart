import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// Resolves video paths from various sources to file system paths.
///
/// Handles:
/// - Asset paths (e.g., 'assets/video.mp4')
/// - Package asset paths (e.g., 'packages/my_pkg/assets/video.mp4')
/// - File paths (passed through directly)
/// - URLs (downloaded to temp directory)
///
/// Example:
/// ```dart
/// final resolver = VideoPathResolver();
/// final result = await resolver.resolve('assets/demo_data/video.mp4');
/// // Use result.path with FFmpeg
/// // When done, call result.cleanup() if result.needsCleanup is true
/// ```
class VideoPathResolver {
  /// Cache of resolved paths to avoid re-copying assets.
  static final Map<String, ResolvedVideoPath> _cache = {};

  /// Resolves a video path to a file system path.
  ///
  /// Returns a [ResolvedVideoPath] containing the resolved path and
  /// cleanup information.
  Future<ResolvedVideoPath> resolve(String videoPath) async {
    // Check cache first
    if (_cache.containsKey(videoPath)) {
      final cached = _cache[videoPath]!;
      // Verify the file still exists
      if (File(cached.path).existsSync()) {
        return cached;
      }
      // File was deleted, remove from cache
      _cache.remove(videoPath);
    }

    ResolvedVideoPath result;

    if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
      // URL - download to temp
      result = await _downloadUrl(videoPath);
    } else if (videoPath.startsWith('assets/') ||
        videoPath.startsWith('packages/')) {
      // Asset - copy to temp
      result = await _copyAssetToTemp(videoPath);
    } else {
      // File path - use directly
      result = ResolvedVideoPath(
        path: videoPath,
        needsCleanup: false,
        originalPath: videoPath,
      );
    }

    // Cache the result
    _cache[videoPath] = result;
    return result;
  }

  /// Copies an asset to the temp directory.
  Future<ResolvedVideoPath> _copyAssetToTemp(String assetPath) async {
    try {
      FluvieLogger.debug('Loading asset: $assetPath', module: 'resolver');
      final data = await rootBundle.load(assetPath);
      FluvieLogger.debug(
        'Asset loaded, size: ${data.lengthInBytes} bytes',
        module: 'resolver',
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = _sanitizeFileName(assetPath);
      final file = File('${tempDir.path}/fluvie_video_$fileName');
      FluvieLogger.debug('Target file: ${file.path}', module: 'resolver');

      // Check if already copied
      if (file.existsSync()) {
        FluvieLogger.debug('File already exists, reusing', module: 'resolver');
        return ResolvedVideoPath(
          path: file.path,
          needsCleanup: false, // Keep cached copy
          originalPath: assetPath,
        );
      }

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await file.writeAsBytes(bytes, flush: true);
      FluvieLogger.debug('File written successfully', module: 'resolver');

      return ResolvedVideoPath(
        path: file.path,
        needsCleanup: false, // Keep for caching
        originalPath: assetPath,
      );
    } catch (e, stack) {
      FluvieLogger.error(
        'Failed to load asset: $assetPath',
        module: 'resolver',
        error: e,
        stackTrace: stack,
      );
      throw VideoPathResolverException(
        'Failed to load asset',
        details: 'Asset: $assetPath\nError: $e',
      );
    }
  }

  /// Downloads a URL to the temp directory.
  Future<ResolvedVideoPath> _downloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        client.close(force: true);
        throw VideoPathResolverException(
          'Failed to download video',
          details: 'URL: $url\nStatus: ${response.statusCode}',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = _sanitizeFileName(
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'video_download',
      );
      final file = File('${tempDir.path}/fluvie_download_$fileName');

      final sink = file.openWrite();
      await response.forEach(sink.add);
      await sink.flush();
      await sink.close();
      client.close(force: true);

      return ResolvedVideoPath(
        path: file.path,
        needsCleanup: true, // Downloaded files should be cleaned up
        originalPath: url,
      );
    } catch (e) {
      if (e is VideoPathResolverException) rethrow;
      throw VideoPathResolverException(
        'Failed to download video',
        details: 'URL: $url\nError: $e',
      );
    }
  }

  /// Sanitizes a file name for safe file system use.
  String _sanitizeFileName(String input) {
    // Extract just the filename part
    final parts = input.split('/');
    final filename = parts.last;
    return filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Clears the resolver cache.
  ///
  /// This does NOT delete the cached files. Use [cleanupAll] to
  /// delete cached files.
  static void clearCache() {
    _cache.clear();
  }

  /// Deletes all cached video files from the temp directory.
  static Future<void> cleanupAll() async {
    for (final entry in _cache.values) {
      if (entry.needsCleanup) {
        try {
          final file = File(entry.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }
    _cache.clear();
  }
}

/// Result of resolving a video path.
class ResolvedVideoPath {
  /// The resolved file system path.
  final String path;

  /// Whether this file should be cleaned up when done.
  final bool needsCleanup;

  /// The original path/URL that was resolved.
  final String originalPath;

  const ResolvedVideoPath({
    required this.path,
    required this.needsCleanup,
    required this.originalPath,
  });

  /// Deletes the resolved file if it needs cleanup.
  Future<void> cleanup() async {
    if (needsCleanup) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }
}

/// Exception thrown when video path resolution fails.
class VideoPathResolverException implements Exception {
  /// Error message.
  final String message;

  /// Additional details about the error.
  final String? details;

  VideoPathResolverException(this.message, {this.details});

  @override
  String toString() {
    if (details != null) {
      return 'VideoPathResolverException: $message\nDetails: $details';
    }
    return 'VideoPathResolverException: $message';
  }
}
