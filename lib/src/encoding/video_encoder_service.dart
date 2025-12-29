import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/audio_config.dart';
import '../domain/render_config.dart';
import '../exceptions/fluvie_exceptions.dart';
import '../utils/logger.dart';
import 'ffmpeg_filter_graph_builder.dart';

/// Factory function for creating [Process] instances.
///
/// Used for dependency injection in testing to mock FFmpeg process execution.
typedef ProcessFactory =
    Future<Process> Function(String executable, List<String> arguments);

/// Provider function for obtaining temporary directories.
///
/// Used for dependency injection in testing to control temp file locations.
typedef TempDirProvider = Future<Directory> Function();

/// Represents an active video encoding session with FFmpeg.
///
/// A session encapsulates the lifecycle of a single FFmpeg encoding process,
/// providing access to:
/// - The stdin sink for writing raw frame data
/// - A completion future that resolves when encoding finishes
/// - Methods to gracefully close or forcefully cancel the encoding
///
/// Example usage:
/// ```dart
/// final session = await encoderService.startEncoding(
///   config: renderConfig,
///   outputFileName: 'output.mp4',
/// );
///
/// // Write frames to stdin
/// for (final frame in frames) {
///   session.sink.add(frame);
/// }
///
/// // Close stdin and wait for completion
/// await session.close();
/// final outputPath = await session.completed;
/// ```
///
/// **Important**: Always call [close] when done writing frames to allow
/// FFmpeg to finalize the video file. Use [cancel] to abort encoding.
class VideoEncodingSession {
  final IOSink _stdin;
  final Future<String> _completion;
  final Process _process;

  /// Creates a new encoding session.
  ///
  /// Typically constructed internally by [VideoEncoderService.startEncoding].
  VideoEncodingSession({
    required IOSink stdin,
    required Future<String> completion,
    required Process process,
  }) : _stdin = stdin,
       _completion = completion,
       _process = process;

  /// The stdin sink for writing raw frame data to FFmpeg.
  ///
  /// Write PNG or raw RGBA bytes to this sink depending on the frame format
  /// configured in [EncodingConfig.frameFormat].
  IOSink get sink => _stdin;

  /// A future that completes when FFmpeg finishes encoding.
  ///
  /// Resolves to the absolute path of the output video file.
  ///
  /// **Important**: Only completes after [close] is called and FFmpeg
  /// has finished processing all frames.
  Future<String> get completed => _completion;

  /// Gracefully closes the encoding session.
  ///
  /// Flushes and closes stdin, signaling to FFmpeg that no more frames
  /// will be written. FFmpeg will then finalize the video file.
  ///
  /// After calling this, await [completed] to get the output path.
  Future<void> close() async {
    FluvieLogger.debug('Flushing stdin to FFmpeg...', module: 'encoder');
    await _stdin.flush();
    FluvieLogger.debug('Closing stdin...', module: 'encoder');
    await _stdin.close();
    FluvieLogger.debug(
      'Stdin closed, FFmpeg should now finalize encoding',
      module: 'encoder',
    );
  }

  /// Forcefully cancels the encoding session.
  ///
  /// Immediately closes stdin and kills the FFmpeg process. Use this when
  /// you need to abort encoding (e.g., due to errors or user cancellation).
  ///
  /// The [completed] future will reject with an error.
  Future<void> cancel() async {
    _stdin.close();
    _process.kill();
  }
}

/// Service for encoding videos using FFmpeg.
///
/// Orchestrates the video encoding pipeline by:
/// 1. Building FFmpeg filter graphs from [RenderConfig]
/// 2. Starting FFmpeg processes with appropriate arguments
/// 3. Managing stdin for frame data input
/// 4. Handling audio track mixing and embedded video clips
/// 5. Monitoring FFmpeg output and error streams
///
/// Example usage:
/// ```dart
/// final encoderService = VideoEncoderService();
///
/// final session = await encoderService.startEncoding(
///   config: renderConfig,
///   outputFileName: 'my-video.mp4',
/// );
///
/// // Write frames (from FrameSequencer)
/// for (int i = 0; i < totalFrames; i++) {
///   final frameBytes = await captureFrame(i);
///   session.sink.add(frameBytes);
/// }
///
/// await session.close();
/// final outputPath = await session.completed;
/// print('Video saved to: $outputPath');
/// ```
///
/// **Threading**: This service spawns FFmpeg as a separate process.
/// Frame writing happens asynchronously via [VideoEncodingSession.sink].
///
/// **Error Handling**: Throws [FFmpegExecutionException] if FFmpeg fails,
/// [InvalidConfigurationException] for invalid configs, and
/// [AudioProcessingException] for audio-related errors.
///
/// See also:
/// - [VideoEncodingSession] for managing active encoding sessions
/// - [RenderConfig] for configuration details
/// - [FFmpegFilterGraphBuilder] for filter graph generation
class VideoEncoderService {
  final ProcessFactory _processFactory;
  final TempDirProvider _tempDirProvider;
  VideoEncodingSession? _activeSession;

  /// Creates a new video encoder service.
  ///
  /// Optionally accepts:
  /// - [processFactory]: Custom process factory for testing (defaults to [Process.start])
  /// - [tempDirProvider]: Custom temp directory provider for testing
  ///   (defaults to [getTemporaryDirectory])
  VideoEncoderService({
    ProcessFactory? processFactory,
    TempDirProvider? tempDirProvider,
  }) : _processFactory = processFactory ?? Process.start,
       _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  /// Starts a new video encoding session.
  ///
  /// Creates an FFmpeg process configured according to [config] and begins
  /// encoding to [outputFileName] in the temporary directory.
  ///
  /// **Parameters:**
  /// - [config]: The render configuration containing composition details,
  ///   encoding settings, audio tracks, and embedded video clips
  /// - [outputFileName]: Name of the output file (e.g., 'output.mp4')
  ///
  /// **Returns:** A [VideoEncodingSession] that allows writing frames and
  /// monitoring completion.
  ///
  /// **Throws:**
  /// - [InvalidConfigurationException] if a session is already active or
  ///   if the configuration is invalid
  /// - [AudioProcessingException] if audio file processing fails
  /// - [FFmpegExecutionException] if FFmpeg cannot be started
  ///
  /// Example:
  /// ```dart
  /// final session = await encoderService.startEncoding(
  ///   config: RenderConfig(
  ///     width: 1920,
  ///     height: 1080,
  ///     fps: 30,
  ///     durationInFrames: 300,
  ///     encoding: EncodingConfig(quality: Quality.high),
  ///   ),
  ///   outputFileName: 'my-video.mp4',
  /// );
  /// ```
  Future<VideoEncodingSession> startEncoding({
    required RenderConfig config,
    required String outputFileName,
  }) async {
    if (_activeSession != null) {
      throw InvalidConfigurationException(
        'An encoding session is already active',
        fieldName: 'session',
      );
    }

    final tempDir = await _tempDirProvider();
    final outputPath = '${tempDir.path}/$outputFileName';
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final encoding = config.encoding ?? const EncodingConfig();
    final resolvedCrf =
        encoding.crfOverride ?? _crfForQuality(encoding.quality);
    final preset =
        encoding.presetOverride ?? _presetForQuality(encoding.quality);

    // Resolve embedded video inputs
    final videoInputs = await _resolveVideoInputs(config);

    // Resolve audio inputs
    final audioInputs = await _resolveAudioInputs(config);

    // Build filter graph
    final filterGraph = FFmpegFilterGraphBuilder().build(config);

    // Build input arguments based on frame format
    final args = <String>['-y'];
    args.addAll(_inputArgsForFormat(encoding.frameFormat, config));

    // Add embedded video inputs (with seek for trim)
    for (final input in videoInputs) {
      if (input.seekSeconds > 0) {
        args.addAll(['-ss', input.seekSeconds.toStringAsFixed(6)]);
      }
      args.addAll(['-i', input.path]);
    }

    // Add audio inputs
    for (final input in audioInputs) {
      args.addAll(['-i', input.path]);
    }

    args.addAll([
      '-filter_complex',
      filterGraph.graph,
      '-map',
      filterGraph.videoOutputLabel,
    ]);

    if (filterGraph.audioOutputLabel != null) {
      args.addAll([
        '-map',
        filterGraph.audioOutputLabel!,
        '-c:a',
        'aac',
        '-b:a',
        '192k',
      ]);
    } else {
      args.add('-an');
    }

    args.addAll([
      '-c:v',
      'libx264',
      '-preset',
      preset,
      '-crf',
      '$resolvedCrf',
      '-pix_fmt',
      'yuv420p',
      outputPath,
    ]);

    Future<void> cleanup() async {
      // Clean up temporary video files
      for (final input in videoInputs.where((e) => e.needsCleanup)) {
        final file = File(input.path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {
            // Ignore cleanup errors.
          }
        }
      }
      // Clean up temporary audio files
      for (final input in audioInputs.where((e) => e.needsCleanup)) {
        final file = File(input.path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {
            // Ignore cleanup errors.
          }
        }
      }
    }

    final process = await _processFactory('ffmpeg', args);

    // Log FFmpeg command details
    final logLines = <String>['Embedded Video Inputs: ${videoInputs.length}'];
    for (var i = 0; i < videoInputs.length; i++) {
      final input = videoInputs[i];
      final displayPath = input.path.length > 40
          ? '...${input.path.substring(input.path.length - 40)}'
          : input.path;
      logLines.add('  Input ${i + 1}: $displayPath');
      logLines.add('    seekSeconds: ${input.seekSeconds.toStringAsFixed(2)}');
    }
    logLines.add('Separate Audio Inputs: ${audioInputs.length}');
    for (var i = 0; i < audioInputs.length; i++) {
      final input = audioInputs[i];
      final displayPath = input.path.length > 40
          ? '...${input.path.substring(input.path.length - 40)}'
          : input.path;
      logLines.add('  Input ${i + 1 + videoInputs.length}: $displayPath');
    }
    logLines.add(
      'Filter Graph audioOutputLabel: ${filterGraph.audioOutputLabel ?? 'NULL'}',
    );
    logLines.add('Filter Graph:');
    final filterParts = filterGraph.graph.split(';');
    for (final part in filterParts) {
      logLines.add('  $part');
    }
    FluvieLogger.box('FFmpeg Command', logLines, module: 'encoder');
    FluvieLogger.debug(
      'Full FFmpeg command: ffmpeg ${args.join(' ')}',
      module: 'encoder',
    );

    // Drain stdout to avoid blocking
    unawaited(process.stdout.drain<void>());

    final stderrBuffer = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    final completion = Completer<String>();
    process.exitCode.then((code) async {
      FluvieLogger.debug(
        'FFmpeg process exited with code $code',
        module: 'encoder',
      );
      _activeSession = null;
      FluvieLogger.debug('Cleaning up temporary files...', module: 'encoder');
      await cleanup();
      FluvieLogger.debug('Cleanup complete', module: 'encoder');
      if (code == 0) {
        FluvieLogger.info('Encoding successful!', module: 'encoder');
        completion.complete(outputPath);
      } else {
        final stderr = stderrBuffer.toString();
        FluvieLogger.error(
          'FFmpeg failed! Exit code: $code',
          module: 'encoder',
          error: stderr,
        );
        completion.completeError(
          Exception('FFmpeg failed (exit code $code): $stderr'),
        );
      }
    });

    final session = VideoEncodingSession(
      stdin: process.stdin,
      completion: completion.future,
      process: process,
    );

    _activeSession = session;
    return session;
  }

  /// Resolves embedded video inputs to file paths.
  ///
  /// Handles asset paths by copying to temp, file paths directly,
  /// and URLs by downloading.
  Future<List<_ResolvedVideoInput>> _resolveVideoInputs(
    RenderConfig config,
  ) async {
    if (config.embeddedVideos.isEmpty) {
      return const [];
    }

    final inputs = <_ResolvedVideoInput>[];

    for (final video in config.embeddedVideos) {
      final videoPath = video.videoPath;

      // Determine source type from path
      if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
        // URL - download to temp
        final resolved = await _downloadUrl(videoPath);
        inputs.add(
          _ResolvedVideoInput(
            path: resolved.path,
            seekSeconds: video.trimStartSeconds,
            needsCleanup: true,
          ),
        );
      } else if (videoPath.startsWith('assets/') ||
          videoPath.startsWith('packages/')) {
        // Asset - copy to temp
        final resolved = await _writeAssetToTemp(videoPath);
        inputs.add(
          _ResolvedVideoInput(
            path: resolved.path,
            seekSeconds: video.trimStartSeconds,
            needsCleanup: true,
          ),
        );
      } else {
        // File path - use directly
        inputs.add(
          _ResolvedVideoInput(
            path: videoPath,
            seekSeconds: video.trimStartSeconds,
          ),
        );
      }
    }

    return inputs;
  }

  Future<List<_ResolvedAudioInput>> _resolveAudioInputs(
    RenderConfig config,
  ) async {
    if (config.audioTracks.isEmpty) {
      return const [];
    }

    final inputs = <_ResolvedAudioInput>[];

    for (final track in config.audioTracks) {
      final source = track.source;
      switch (source.type) {
        case AudioSourceType.asset:
          inputs.add(await _writeAssetToTemp(source.uri));
          break;
        case AudioSourceType.file:
          inputs.add(_ResolvedAudioInput(path: source.uri));
          break;
        case AudioSourceType.url:
          inputs.add(await _downloadUrl(source.uri));
          break;
      }
    }

    return inputs;
  }

  Future<_ResolvedAudioInput> _writeAssetToTemp(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final tempDir = await _tempDirProvider();
    final fileName = _sanitizeFileName(assetPath);
    final file = File('${tempDir.path}/$fileName');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await file.writeAsBytes(bytes, flush: true);
    return _ResolvedAudioInput(path: file.path, needsCleanup: true);
  }

  Future<_ResolvedAudioInput> _downloadUrl(String url) async {
    final uri = Uri.parse(url);
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      client.close(force: true);
      throw AudioProcessingException(
        'Failed to download audio from URL',
        audioFilePath: url,
        operation: 'download',
      );
    }

    final tempDir = await _tempDirProvider();
    final fileName = _sanitizeFileName(
      uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'audio_download',
    );
    final file = File('${tempDir.path}/$fileName');
    final sink = file.openWrite();
    await response.forEach(sink.add);
    await sink.flush();
    await sink.close();
    client.close(force: true);

    return _ResolvedAudioInput(path: file.path, needsCleanup: true);
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}

List<String> _inputArgsForFormat(FrameFormat format, RenderConfig config) {
  switch (format) {
    case FrameFormat.png:
      // PNG format: supports transparency, slightly slower
      return [
        '-f',
        'image2pipe',
        '-c:v',
        'png',
        '-r',
        '${config.timeline.fps}',
        '-i',
        '-',
      ];
    case FrameFormat.rawRgba:
      // Raw RGBA: fastest, no encoding overhead
      return [
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgba',
        '-s',
        '${config.timeline.width}x${config.timeline.height}',
        '-r',
        '${config.timeline.fps}',
        '-i',
        '-',
      ];
  }
}

int _crfForQuality(RenderQuality quality) {
  switch (quality) {
    case RenderQuality.low:
      return 30;
    case RenderQuality.medium:
      return 23;
    case RenderQuality.high:
      return 18;
    case RenderQuality.lossless:
      return 0;
  }
}

String _presetForQuality(RenderQuality quality) {
  switch (quality) {
    case RenderQuality.low:
      return 'veryfast';
    case RenderQuality.medium:
      return 'medium';
    case RenderQuality.high:
      return 'slow';
    case RenderQuality.lossless:
      return 'veryslow';
  }
}

class _ResolvedAudioInput {
  final String path;
  final bool needsCleanup;

  const _ResolvedAudioInput({required this.path, this.needsCleanup = false});
}

/// Resolved video input with path and seek offset.
class _ResolvedVideoInput {
  /// Path to the video file.
  final String path;

  /// Seek offset in seconds (for trim).
  final double seekSeconds;

  /// Whether to delete this file after encoding.
  final bool needsCleanup;

  const _ResolvedVideoInput({
    required this.path,
    this.seekSeconds = 0,
    this.needsCleanup = false,
  });
}
