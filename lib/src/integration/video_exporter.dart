import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../declarative/core/video.dart';
import '../domain/render_config.dart';
import '../presentation/render_controller.dart';
import '../presentation/render_mode_context.dart';
import '../presentation/time_consumer.dart';
import '../capture/frame_sequencer.dart';
import '../encoding/video_encoder_service.dart';
import '../utils/logger.dart';
import '../utils/file_saver.dart';

/// Progress event emitted during video export.
class VideoExportProgress {
  /// Current frame being rendered.
  final int currentFrame;

  /// Total frames in the video.
  final int totalFrames;

  /// Current render phase.
  final VideoExportPhase phase;

  /// Time elapsed since export started.
  final Duration elapsed;

  /// Estimated time remaining based on current rate.
  Duration? get estimatedTimeRemaining {
    if (currentFrame == 0 || phase != VideoExportPhase.capturing) return null;
    final msPerFrame = elapsed.inMilliseconds / currentFrame;
    final remainingFrames = totalFrames - currentFrame;
    return Duration(milliseconds: (msPerFrame * remainingFrames).round());
  }

  /// Progress as a value from 0.0 to 1.0.
  double get progress => totalFrames > 0 ? currentFrame / totalFrames : 0.0;

  /// Creates a progress event.
  const VideoExportProgress({
    required this.currentFrame,
    required this.totalFrames,
    required this.phase,
    required this.elapsed,
  });

  @override
  String toString() =>
      'VideoExportProgress(frame: $currentFrame/$totalFrames, phase: $phase, progress: ${(progress * 100).toStringAsFixed(1)}%)';
}

/// Phases of the video export process.
enum VideoExportPhase {
  /// Initializing render service and FFmpeg.
  initializing,

  /// Capturing frames from widget tree.
  capturing,

  /// FFmpeg is encoding the final video.
  encoding,

  /// Export complete, file ready.
  complete,

  /// Export failed with error.
  failed,
}

/// Fluent builder for rendering and exporting Fluvie videos.
///
/// [VideoExporter] simplifies the rendering workflow by:
/// - Automatically extracting configuration from [Video] widgets
/// - Managing [RenderController] and [RenderService] internally
/// - Providing callback or stream-based progress updates
/// - Handling platform-specific file saving
///
/// ## Basic Usage
///
/// ```dart
/// final path = await VideoExporter(myVideo).render();
/// print('Saved to: $path');
/// ```
///
/// ## With Progress Tracking
///
/// ```dart
/// final path = await VideoExporter(myVideo)
///   .withProgress((progress) => print('${(progress * 100).toInt()}%'))
///   .withQuality(RenderQuality.high)
///   .render();
/// ```
///
/// ## Using Stream for Reactive Updates
///
/// ```dart
/// await for (final event in VideoExporter(myVideo).renderStream()) {
///   print('Phase: ${event.phase}, Progress: ${event.progress}');
///   if (event.phase == VideoExportPhase.complete) {
///     print('Done!');
///   }
/// }
/// ```
///
/// ## Render and Save in One Step
///
/// ```dart
/// await VideoExporter(myVideo)
///   .withFileName('my_video.mp4')
///   .renderAndSave();
/// ```
class VideoExporter {
  final Video _video;
  RenderQuality _quality = RenderQuality.medium;
  void Function(double progress)? _progressCallback;
  void Function(int frame, int totalFrames)? _frameCallback;
  String _outputFileNameValue = 'output.mp4';
  EncodingConfig? _encodingConfig;

  /// The output file name. Exposed for testing.
  @visibleForTesting
  String get outputFileName => _outputFileNameValue;

  /// Creates a new exporter for the given video.
  VideoExporter(this._video);

  /// Sets the render quality preset.
  ///
  /// Defaults to [RenderQuality.medium].
  ///
  /// Quality presets:
  /// - [RenderQuality.low]: CRF 30, smaller file, faster
  /// - [RenderQuality.medium]: CRF 23, balanced
  /// - [RenderQuality.high]: CRF 18, larger file, slower
  /// - [RenderQuality.lossless]: CRF 0, maximum quality
  VideoExporter withQuality(RenderQuality quality) {
    _quality = quality;
    return this;
  }

  /// Sets a callback for overall progress updates (0.0 to 1.0).
  ///
  /// Example:
  /// ```dart
  /// VideoExporter(video)
  ///   .withProgress((p) => setState(() => _progress = p))
  ///   .render();
  /// ```
  VideoExporter withProgress(void Function(double progress) callback) {
    _progressCallback = callback;
    return this;
  }

  /// Sets a callback for per-frame progress updates.
  ///
  /// Example:
  /// ```dart
  /// VideoExporter(video)
  ///   .withFrameProgress((frame, total) {
  ///     print('Frame $frame of $total');
  ///   })
  ///   .render();
  /// ```
  VideoExporter withFrameProgress(
    void Function(int frame, int totalFrames) callback,
  ) {
    _frameCallback = callback;
    return this;
  }

  /// Sets the output file name.
  ///
  /// Defaults to `'output.mp4'`.
  /// The file is created in the system temp directory.
  VideoExporter withFileName(String fileName) {
    _outputFileNameValue = fileName;
    return this;
  }

  /// Sets custom encoding configuration.
  ///
  /// Overrides quality preset if set.
  ///
  /// Example:
  /// ```dart
  /// VideoExporter(video)
  ///   .withEncoding(EncodingConfig(
  ///     quality: RenderQuality.high,
  ///     frameFormat: FrameFormat.png, // For transparency
  ///   ))
  ///   .render();
  /// ```
  VideoExporter withEncoding(EncodingConfig config) {
    _encodingConfig = config;
    return this;
  }

  /// Builds the render configuration from the video.
  @visibleForTesting
  RenderConfig buildConfig() {
    final encoding = _encodingConfig ?? EncodingConfig(quality: _quality);

    return RenderConfig(
      timeline: TimelineConfig(
        fps: _video.fps,
        durationInFrames: _video.totalDuration,
        width: _video.width,
        height: _video.height,
      ),
      sequences: [],
      embeddedVideos: _video.extractEmbeddedVideoConfigs(),
      encoding: encoding,
    );
  }

  /// Renders the video and returns the output file path.
  ///
  /// This method:
  /// 1. Creates an off-screen Flutter widget tree
  /// 2. Captures each frame using [RenderService]
  /// 3. Encodes to MP4 using FFmpeg
  ///
  /// Returns the path to the rendered video file in the system temp directory.
  ///
  /// Throws [FFmpegExecutionException] if rendering fails.
  ///
  /// Example:
  /// ```dart
  /// final path = await VideoExporter(myVideo).render();
  /// print('Video saved to: $path');
  /// ```
  Future<String> render() async {
    final config = buildConfig();
    final totalFrames = _video.totalDuration;

    FluvieLogger.box(
      'VideoExporter.render()',
      [
        'Video: ${_video.width}x${_video.height} @ ${_video.fps}fps',
        'Total frames: $totalFrames',
        'Quality: $_quality',
        'Output: $_outputFileNameValue',
      ],
      module: 'exporter',
      level: FluvieLogLevel.info,
    );

    // Create rendering infrastructure
    final renderController = RenderController();
    final encoderService = VideoEncoderService();
    final stopwatch = Stopwatch()..start();

    // Notify initializing phase
    _progressCallback?.call(0.0);
    _frameCallback?.call(0, totalFrames);

    // Create widget for rendering
    final widget = RepaintBoundary(
      key: renderController.boundaryKey,
      child: SizedBox(
        width: _video.width.toDouble(),
        height: _video.height.toDouble(),
        child: RenderModeProvider(
          isRendering: true,
          frameReadyNotifier: renderController.frameReadyNotifier,
          child: FrameProvider(frame: 0, child: _video),
        ),
      ),
    );

    // Use the pipeline overlay approach
    final completer = Completer<String>();

    // Schedule frame capture using the overlay
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final path = await _executeRender(
          config: config,
          renderController: renderController,
          encoderService: encoderService,
          widget: widget,
          stopwatch: stopwatch,
        );
        if (!completer.isCompleted) {
          completer.complete(path);
        }
      } catch (e, stack) {
        if (!completer.isCompleted) {
          completer.completeError(e, stack);
        }
      }
    });

    return completer.future;
  }

  Future<String> _executeRender({
    required RenderConfig config,
    required RenderController renderController,
    required VideoEncoderService encoderService,
    required Widget widget,
    required Stopwatch stopwatch,
  }) async {
    final totalFrames = config.timeline.durationInFrames;

    // Start FFmpeg encoding session
    final session = await encoderService.startEncoding(
      config: config,
      outputFileName: _outputFileNameValue,
    );

    try {
      // Create frame sequencer
      final sequencer = FrameSequencer(renderController.boundaryKey);

      // Calculate pixel ratio
      final pixelRatio = 1.0; // Using exact dimensions

      // Capture frames
      for (int frame = 0; frame < totalFrames; frame++) {
        // Update frame in widget tree
        renderController.setFrame(frame);

        // Wait for frame to rasterize
        await _waitForRasterization();

        // Wait for any pending async operations
        final success = await renderController.frameReadyNotifier
            .waitForAllFramesWithTimeout(const Duration(seconds: 5));

        if (!success) {
          FluvieLogger.warning(
            'Frame $frame: Timeout waiting for pending operations',
            module: 'exporter',
          );
        }

        // Capture frame
        final bytes = await sequencer.captureFrameRawExact(
          pixelRatio: pixelRatio,
          targetWidth: config.timeline.width,
          targetHeight: config.timeline.height,
        );

        // Write to FFmpeg
        session.sink.add(bytes);

        // Update progress
        final progress = (frame + 1) / totalFrames;
        _progressCallback?.call(progress);
        _frameCallback?.call(frame + 1, totalFrames);

        FluvieLogger.debug(
          'Frame ${frame + 1}/$totalFrames captured (${bytes.length} bytes)',
          module: 'exporter',
        );
      }

      // Close session and wait for encoding
      await session.close();
      final outputPath = await session.completed;

      stopwatch.stop();
      FluvieLogger.info(
        'Export complete: $outputPath (${stopwatch.elapsedMilliseconds}ms)',
        module: 'exporter',
      );

      return outputPath;
    } catch (e) {
      await session.cancel();
      rethrow;
    }
  }

  Future<void> _waitForRasterization() async {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    await completer.future;
  }

  /// Renders the video and returns the raw bytes.
  ///
  /// Useful for web platform where file system access is limited,
  /// or when you need to process the video in memory.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await VideoExporter(myVideo).renderToBytes();
  /// // Use bytes for upload, streaming, etc.
  /// ```
  Future<Uint8List> renderToBytes() async {
    final path = await render();
    final file = File(path);
    return file.readAsBytes();
  }

  /// Renders and automatically saves using platform-specific download.
  ///
  /// - On desktop: Copies to Downloads folder
  /// - On mobile: Uses share sheet or file picker
  /// - On web: Triggers browser download
  ///
  /// Example:
  /// ```dart
  /// await VideoExporter(myVideo)
  ///   .withFileName('my_awesome_video.mp4')
  ///   .renderAndSave();
  /// ```
  Future<void> renderAndSave() async {
    final path = await render();
    await FileSaver.save(path, suggestedName: _outputFileNameValue);
  }

  /// Creates a stream that emits progress events during rendering.
  ///
  /// Alternative to callback-based progress for reactive patterns.
  ///
  /// Example:
  /// ```dart
  /// await for (final event in VideoExporter(myVideo).renderStream()) {
  ///   switch (event.phase) {
  ///     case VideoExportPhase.initializing:
  ///       print('Starting...');
  ///     case VideoExportPhase.capturing:
  ///       print('Progress: ${(event.progress * 100).toInt()}%');
  ///     case VideoExportPhase.encoding:
  ///       print('Encoding...');
  ///     case VideoExportPhase.complete:
  ///       print('Done!');
  ///     case VideoExportPhase.failed:
  ///       print('Failed!');
  ///   }
  /// }
  /// ```
  Stream<VideoExportProgress> renderStream() async* {
    final totalFrames = _video.totalDuration;
    final stopwatch = Stopwatch()..start();

    yield VideoExportProgress(
      currentFrame: 0,
      totalFrames: totalFrames,
      phase: VideoExportPhase.initializing,
      elapsed: stopwatch.elapsed,
    );

    try {
      // Set up callbacks to emit stream events
      int lastFrame = 0;
      final streamController = StreamController<VideoExportProgress>();

      _progressCallback = (_) {};
      _frameCallback = (frame, total) {
        if (frame != lastFrame) {
          lastFrame = frame;
          streamController.add(
            VideoExportProgress(
              currentFrame: frame,
              totalFrames: total,
              phase: VideoExportPhase.capturing,
              elapsed: stopwatch.elapsed,
            ),
          );
        }
      };

      // Start render
      final renderFuture = render();

      // Yield capturing events
      await for (final event in streamController.stream) {
        yield event;
        if (event.currentFrame >= totalFrames - 1) break;
      }

      // Wait for render to complete
      yield VideoExportProgress(
        currentFrame: totalFrames,
        totalFrames: totalFrames,
        phase: VideoExportPhase.encoding,
        elapsed: stopwatch.elapsed,
      );

      await renderFuture;

      yield VideoExportProgress(
        currentFrame: totalFrames,
        totalFrames: totalFrames,
        phase: VideoExportPhase.complete,
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      yield VideoExportProgress(
        currentFrame: 0,
        totalFrames: totalFrames,
        phase: VideoExportPhase.failed,
        elapsed: stopwatch.elapsed,
      );
      rethrow;
    }
  }
}
