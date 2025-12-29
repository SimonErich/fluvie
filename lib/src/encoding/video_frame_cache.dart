import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../utils/logger.dart';
import 'frame_extraction_service.dart';

/// LRU cache for extracted video frames with sliding window support.
///
/// This cache provides efficient memory management for video frame
/// extraction by:
/// - Using LRU (Least Recently Used) eviction
/// - Supporting a sliding window for sequential playback
/// - Enforcing maximum frame count and memory limits
/// - Background preloading of frames ahead of playback
///
/// Example:
/// ```dart
/// final cache = VideoFrameCache(
///   maxFrames: 90,            // ~3 seconds at 30fps
///   maxMemoryBytes: 500 * 1024 * 1024,  // 500MB
/// );
///
/// // Get or load a frame
/// final frame = await cache.getOrExtract(
///   extractionService,
///   videoPath: 'video.mp4',
///   frameNumber: 100,
///   sourceFps: 30.0,
///   width: 800,
///   height: 450,
/// );
///
/// // Preload frames ahead
/// cache.preloadAhead(
///   extractionService,
///   videoPath: 'video.mp4',
///   currentFrame: 100,
///   aheadCount: 30,
///   sourceFps: 30.0,
///   width: 800,
///   height: 450,
/// );
/// ```
class VideoFrameCache {
  /// Maximum number of frames to keep in cache.
  final int maxFrames;

  /// Maximum memory usage in bytes.
  final int maxMemoryBytes;

  /// Internal cache storage.
  /// Key format: "$videoPath:$frameNumber"
  final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();

  /// Current memory usage in bytes.
  int _currentMemoryBytes = 0;

  /// Pending extraction futures to avoid duplicate extractions.
  final Map<String, Future<ExtractedFrame>> _pendingExtractions = {};

  /// Active preload operations.
  final Set<String> _activePreloads = {};

  /// Creates a new VideoFrameCache.
  ///
  /// [maxFrames] - Maximum number of frames to cache (default: 90).
  /// [maxMemoryBytes] - Maximum memory usage (default: 500MB).
  VideoFrameCache({
    this.maxFrames = 90,
    this.maxMemoryBytes = 500 * 1024 * 1024,
  });

  /// Gets a frame from cache if available.
  ExtractedFrame? get(String videoPath, int frameNumber) {
    final key = _makeKey(videoPath, frameNumber);
    final entry = _cache[key];

    if (entry != null) {
      // Move to end (most recently used)
      _cache.remove(key);
      _cache[key] = entry;
      return entry.frame;
    }

    return null;
  }

  /// Gets a frame from cache, or extracts it if not cached.
  ///
  /// This method handles deduplication of concurrent extraction requests
  /// for the same frame.
  Future<ExtractedFrame> getOrExtract(
    FrameExtractionService extractionService, {
    required String videoPath,
    required int frameNumber,
    required double sourceFps,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    // Check cache first
    final cached = get(videoPath, frameNumber);
    if (cached != null) {
      return cached;
    }

    final key = _makeKey(videoPath, frameNumber);

    // Check if extraction is already in progress
    final pending = _pendingExtractions[key];
    if (pending != null) {
      return pending;
    }

    // Start new extraction
    final future = _extractAndCache(
      extractionService,
      videoPath: videoPath,
      frameNumber: frameNumber,
      sourceFps: sourceFps,
      width: width,
      height: height,
      fit: fit,
    );

    _pendingExtractions[key] = future;

    try {
      final frame = await future;
      return frame;
    } finally {
      _pendingExtractions.remove(key);
    }
  }

  /// Extracts a frame and adds it to the cache.
  Future<ExtractedFrame> _extractAndCache(
    FrameExtractionService extractionService, {
    required String videoPath,
    required int frameNumber,
    required double sourceFps,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    final frame = await extractionService.extractFrameByNumber(
      videoPath: videoPath,
      frameNumber: frameNumber,
      sourceFps: sourceFps,
      width: width,
      height: height,
      fit: fit,
    );

    put(videoPath, frameNumber, frame);
    return frame;
  }

  /// Stores a frame in the cache.
  void put(String videoPath, int frameNumber, ExtractedFrame frame) {
    final key = _makeKey(videoPath, frameNumber);

    // If already cached, update and move to end
    if (_cache.containsKey(key)) {
      final oldEntry = _cache.remove(key)!;
      _currentMemoryBytes -= oldEntry.frame.sizeInBytes;
    }

    // Evict if necessary
    _evictIfNeeded(frame.sizeInBytes);

    // Add new entry
    _cache[key] = _CacheEntry(frame: frame, videoPath: videoPath);
    _currentMemoryBytes += frame.sizeInBytes;
  }

  /// Checks if a frame is cached.
  bool has(String videoPath, int frameNumber) {
    final key = _makeKey(videoPath, frameNumber);
    return _cache.containsKey(key);
  }

  /// Preloads frames ahead of the current playback position.
  ///
  /// This method starts background extraction of frames that will
  /// likely be needed soon. It's designed to be called frequently
  /// as playback progresses.
  Future<void> preloadAhead(
    FrameExtractionService extractionService, {
    required String videoPath,
    required int currentFrame,
    required int aheadCount,
    required double sourceFps,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
    int? totalFrames,
  }) async {
    final preloadKey = '$videoPath:$currentFrame:$aheadCount';

    // Avoid duplicate preload operations
    if (_activePreloads.contains(preloadKey)) {
      return;
    }

    _activePreloads.add(preloadKey);

    try {
      // Calculate frames to preload
      final framesToPreload = <int>[];
      for (int i = 0; i < aheadCount; i++) {
        final frameNum = currentFrame + i;

        // Skip if beyond total frames
        if (totalFrames != null && frameNum >= totalFrames) {
          break;
        }

        // Skip if already cached or being extracted
        if (!has(videoPath, frameNum) &&
            !_pendingExtractions.containsKey(_makeKey(videoPath, frameNum))) {
          framesToPreload.add(frameNum);
        }
      }

      if (framesToPreload.isEmpty) {
        return;
      }

      // Extract frames in batches for efficiency
      const batchSize = 10;
      for (int i = 0; i < framesToPreload.length; i += batchSize) {
        final batchEnd = (i + batchSize).clamp(0, framesToPreload.length);
        final batch = framesToPreload.sublist(i, batchEnd);

        // Extract batch concurrently
        await Future.wait(
          batch.map(
            (frameNum) => getOrExtract(
              extractionService,
              videoPath: videoPath,
              frameNumber: frameNum,
              sourceFps: sourceFps,
              width: width,
              height: height,
              fit: fit,
            ),
          ),
          eagerError: false,
        );
      }
    } finally {
      _activePreloads.remove(preloadKey);
    }
  }

  /// Preloads frames using range extraction for better efficiency.
  ///
  /// This method extracts multiple frames in a single FFmpeg call,
  /// which is more efficient than extracting them one by one.
  Future<void> preloadRange(
    FrameExtractionService extractionService, {
    required String videoPath,
    required int startFrame,
    required int endFrame,
    required double sourceFps,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    // Check which frames need extraction
    final framesToExtract = <int>[];
    for (int f = startFrame; f <= endFrame; f++) {
      if (!has(videoPath, f)) {
        framesToExtract.add(f);
      }
    }

    if (framesToExtract.isEmpty) {
      return;
    }

    // Find contiguous ranges for efficient extraction
    final ranges = _findContiguousRanges(framesToExtract);

    for (final range in ranges) {
      try {
        final frames = await extractionService.extractFrameRange(
          videoPath: videoPath,
          startFrame: range.start,
          endFrame: range.end,
          sourceFps: sourceFps,
          width: width,
          height: height,
          fit: fit,
        );

        for (final frame in frames) {
          put(videoPath, frame.frameNumber, frame);
        }
      } catch (e) {
        // Log error but continue with other ranges
        FluvieLogger.error(
          'Failed to extract range ${range.start}-${range.end}',
          module: 'cache',
          error: e,
        );
      }
    }
  }

  /// Finds contiguous ranges in a list of frame numbers.
  List<_FrameRange> _findContiguousRanges(List<int> frames) {
    if (frames.isEmpty) return [];

    frames.sort();
    final ranges = <_FrameRange>[];

    int rangeStart = frames[0];
    int rangeEnd = frames[0];

    for (int i = 1; i < frames.length; i++) {
      if (frames[i] == rangeEnd + 1) {
        rangeEnd = frames[i];
      } else {
        ranges.add(_FrameRange(rangeStart, rangeEnd));
        rangeStart = frames[i];
        rangeEnd = frames[i];
      }
    }

    ranges.add(_FrameRange(rangeStart, rangeEnd));
    return ranges;
  }

  /// Evicts entries if needed to make room for new data.
  void _evictIfNeeded(int incomingBytes) {
    // Evict by frame count
    while (_cache.length >= maxFrames && _cache.isNotEmpty) {
      _evictOldest();
    }

    // Evict by memory
    while (_currentMemoryBytes + incomingBytes > maxMemoryBytes &&
        _cache.isNotEmpty) {
      _evictOldest();
    }
  }

  /// Evicts the oldest (least recently used) entry.
  void _evictOldest() {
    if (_cache.isEmpty) return;

    final oldestKey = _cache.keys.first;
    final entry = _cache.remove(oldestKey)!;
    _currentMemoryBytes -= entry.frame.sizeInBytes;
  }

  /// Evicts frames outside the sliding window.
  ///
  /// Call this when playback position changes to free memory
  /// from frames that are no longer needed.
  void evictOutsideWindow({
    required String videoPath,
    required int centerFrame,
    required int windowSize,
  }) {
    final minFrame = centerFrame - windowSize ~/ 2;
    final maxFrame = centerFrame + windowSize ~/ 2;

    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.videoPath == videoPath) {
        final frameNum = _extractFrameNumber(entry.key);
        if (frameNum < minFrame || frameNum > maxFrame) {
          keysToRemove.add(entry.key);
        }
      }
    }

    for (final key in keysToRemove) {
      final entry = _cache.remove(key)!;
      _currentMemoryBytes -= entry.frame.sizeInBytes;
    }
  }

  /// Clears all cached frames for a specific video.
  void clearVideo(String videoPath) {
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.videoPath == videoPath) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      final entry = _cache.remove(key)!;
      _currentMemoryBytes -= entry.frame.sizeInBytes;
    }
  }

  /// Clears the entire cache.
  void clearAll() {
    _cache.clear();
    _currentMemoryBytes = 0;
    _pendingExtractions.clear();
  }

  /// Current number of cached frames.
  int get frameCount => _cache.length;

  /// Current memory usage in bytes.
  int get memoryUsage => _currentMemoryBytes;

  /// Memory usage as a fraction of the maximum (0.0 to 1.0).
  double get memoryUsageRatio =>
      maxMemoryBytes > 0 ? _currentMemoryBytes / maxMemoryBytes : 0.0;

  /// Creates a cache key from video path and frame number.
  String _makeKey(String videoPath, int frameNumber) =>
      '$videoPath:$frameNumber';

  /// Extracts frame number from a cache key.
  int _extractFrameNumber(String key) {
    final parts = key.split(':');
    return int.parse(parts.last);
  }
}

/// Internal cache entry.
class _CacheEntry {
  final ExtractedFrame frame;
  final String videoPath;

  _CacheEntry({required this.frame, required this.videoPath});
}

/// Internal frame range for batch extraction.
class _FrameRange {
  final int start;
  final int end;

  _FrameRange(this.start, this.end);
}

/// Shared cache instance for the application.
///
/// This provides a single cache that can be shared across
/// multiple EmbeddedVideo widgets for better memory efficiency.
class VideoFrameCacheManager {
  static VideoFrameCache? _instance;

  /// Gets the shared cache instance.
  ///
  /// Creates one with default settings if not already created.
  static VideoFrameCache get instance {
    _instance ??= VideoFrameCache();
    return _instance!;
  }

  /// Configures the shared cache with custom settings.
  ///
  /// Must be called before first access to [instance].
  static void configure({
    int maxFrames = 90,
    int maxMemoryBytes = 500 * 1024 * 1024,
  }) {
    _instance = VideoFrameCache(
      maxFrames: maxFrames,
      maxMemoryBytes: maxMemoryBytes,
    );
  }

  /// Disposes the shared cache instance.
  static void dispose() {
    _instance?.clearAll();
    _instance = null;
  }
}
