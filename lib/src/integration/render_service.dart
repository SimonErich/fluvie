import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../declarative/core/video.dart';
import '../domain/render_config.dart';
import '../domain/audio_config.dart';
import '../domain/embedded_video_config.dart';
import '../domain/sync_anchor_info.dart';
import '../exceptions/fluvie_exceptions.dart';
import '../presentation/audio_track.dart';
import '../presentation/render_mode_context.dart';
import '../presentation/video_composition.dart';
import '../presentation/sequence.dart';
import '../presentation/sync_anchor.dart';
import '../capture/frame_sequencer.dart';
import '../capture/frame_pipeline.dart';
import '../encoding/video_encoder_service.dart';
import '../utils/logger.dart';
import '../utils/impeller_checker.dart';

/// Provider for the render service.
final renderServiceProvider = Provider((ref) => RenderService());

/// Service for rendering video compositions to files.
///
/// This service orchestrates the rendering process by:
/// 1. Capturing frames from Flutter widgets
/// 2. Streaming them to FFmpeg for encoding
/// 3. Returning the path to the output file
class RenderService {
  final VideoEncoderService _encoderService;

  /// Creates a render service.
  ///
  /// An optional [encoderService] can be provided for testing.
  RenderService({VideoEncoderService? encoderService})
      : _encoderService = encoderService ?? VideoEncoderService();

  /// Creates a [RenderConfig] from a [VideoComposition] in the widget tree.
  ///
  /// This walks the widget tree to find all [Sequence], [AudioTrack], and
  /// [EmbeddedVideo] widgets and extracts their configuration.
  ///
  /// For [EmbeddedVideo] widgets, we use the [Video.extractEmbeddedVideoConfigs]
  /// method to extract configs directly from the widget tree definition,
  /// since EmbeddedVideo widgets may not be built at the current frame
  /// (they're inside scenes that only render when visible).
  RenderConfig createConfigFromContext(BuildContext context) {
    final composition = VideoComposition.of(context);
    if (composition == null) {
      throw InvalidConfigurationException(
        'No VideoComposition found in context. Ensure your widget tree includes a VideoComposition ancestor.',
        fieldName: 'context',
      );
    }

    final config = RenderConfig(
      timeline: TimelineConfig(
        fps: composition.fps,
        durationInFrames: composition.durationInFrames,
        width: composition.width,
        height: composition.height,
      ),
      sequences: [],
      encoding: composition.encoding,
    );
    final sequences = <SequenceConfig>[];
    final audioTracks = <AudioTrackConfig>[];
    final embeddedVideos = <EmbeddedVideoConfig>[];
    final syncAnchors = <String, SyncAnchorInfo>{};

    // Find the Video widget by looking UP the element tree (it's an ancestor of VideoComposition)
    Video? videoWidget;
    context.visitAncestorElements((element) {
      if (element.widget is Video) {
        videoWidget = element.widget as Video;
        return false; // Stop visiting
      }
      return true; // Continue visiting
    });

    // Also look in descendants in case the context structure is different
    if (videoWidget == null) {
      void visitDescendants(Element element) {
        if (element.widget is Video) {
          videoWidget = element.widget as Video;
        }
        if (element.widget is Sequence) {
          final sequence = element.widget as Sequence;
          sequences.add(sequence.toSequenceConfig());
        }
        if (element.widget is AudioTrack) {
          final track = element.widget as AudioTrack;
          audioTracks.add(track.toAudioConfig());
        }
        if (element.widget is SyncAnchor) {
          final anchor = element.widget as SyncAnchor;
          syncAnchors[anchor.anchorId] = SyncAnchorInfo(
            anchorId: anchor.anchorId,
            startFrame: anchor.startFrame + anchor.startOffset,
            endFrame: anchor.endFrame != null
                ? anchor.endFrame! + anchor.endOffset
                : null,
          );
        }
        element.visitChildren(visitDescendants);
      }

      (context as Element).visitChildren(visitDescendants);
    } else {
      // Video widget found in ancestors, still need to visit descendants for Sequence/AudioTrack/SyncAnchor
      void visitDescendants(Element element) {
        if (element.widget is Sequence) {
          final sequence = element.widget as Sequence;
          sequences.add(sequence.toSequenceConfig());
        }
        if (element.widget is AudioTrack) {
          final track = element.widget as AudioTrack;
          audioTracks.add(track.toAudioConfig());
        }
        if (element.widget is SyncAnchor) {
          final anchor = element.widget as SyncAnchor;
          syncAnchors[anchor.anchorId] = SyncAnchorInfo(
            anchorId: anchor.anchorId,
            startFrame: anchor.startFrame + anchor.startOffset,
            endFrame: anchor.endFrame != null
                ? anchor.endFrame! + anchor.endOffset
                : null,
          );
        }
        element.visitChildren(visitDescendants);
      }

      (context as Element).visitChildren(visitDescendants);
    }

    // Log collected sync anchors
    if (syncAnchors.isNotEmpty) {
      FluvieLogger.debug(
        'Collected ${syncAnchors.length} sync anchors: ${syncAnchors.keys.join(", ")}',
        module: 'render',
      );
    }

    // Extract embedded videos from the Video widget's scene definitions
    // This works even when the EmbeddedVideo widgets aren't built (not visible at frame 0)
    if (videoWidget != null) {
      FluvieLogger.debug(
        'Found Video widget with ${videoWidget!.scenes.length} scenes',
        module: 'render',
      );
      final extractedConfigs = videoWidget!.extractEmbeddedVideoConfigs();
      embeddedVideos.addAll(extractedConfigs);
      FluvieLogger.debug(
        'Extracted ${extractedConfigs.length} embedded videos from Video widget',
        module: 'render',
      );
    } else {
      FluvieLogger.warning(
        'No Video widget found in ancestors or descendants',
        module: 'render',
      );
    }

    // Resolve audio track sync references
    final resolvedAudioTracks = <AudioTrackConfig>[];
    if (syncAnchors.isNotEmpty) {
      // Convert SyncAnchorInfo to the format expected by resolveSync
      final anchorMap = <String, ({int startFrame, int? endFrame})>{};
      for (final entry in syncAnchors.entries) {
        anchorMap[entry.key] = (
          startFrame: entry.value.startFrame,
          endFrame: entry.value.endFrame,
        );
      }

      for (final track in audioTracks) {
        if (track.sync != null && track.sync!.hasSyncConfig) {
          final resolved = track.resolveSync(anchorMap);
          resolvedAudioTracks.add(resolved);
          FluvieLogger.debug(
            'Resolved audio sync: ${track.sync!.syncStartWithAnchor ?? "none"} -> '
            'startFrame=${resolved.startFrame}, duration=${resolved.durationInFrames}',
            module: 'render',
          );
        } else {
          resolvedAudioTracks.add(track);
        }
      }
    } else {
      resolvedAudioTracks.addAll(audioTracks);
    }

    // Log the final render config
    final embeddedVideoLines = <String>[
      'sequences: ${sequences.length}',
      'audioTracks: ${resolvedAudioTracks.length}',
      'embeddedVideos: ${embeddedVideos.length}',
    ];
    for (var i = 0; i < embeddedVideos.length; i++) {
      final v = embeddedVideos[i];
      embeddedVideoLines.add('  [$i] ${v.videoPath}');
      embeddedVideoLines.add(
        '      startFrame=${v.startFrame}, duration=${v.durationInFrames}',
      );
      embeddedVideoLines.add(
        '      includeAudio=${v.includeAudio}, volume=${v.audioVolume}',
      );
    }
    FluvieLogger.box(
      'Final RenderConfig',
      embeddedVideoLines,
      module: 'render',
    );

    return RenderConfig(
      timeline: config.timeline,
      sequences: sequences,
      audioTracks: resolvedAudioTracks,
      embeddedVideos: embeddedVideos,
      encoding: config.encoding,
    );
  }

  Future<String> execute({
    required RenderConfig config,
    required GlobalKey repaintBoundaryKey,
    required Function(int frame) onFrameUpdate,
    FrameReadyNotifier? frameReadyNotifier,
  }) async {
    // Check for Impeller renderer and log warning if Skia is detected
    ImpellerChecker.logWarningIfSkia();

    final sequencer = FrameSequencer(repaintBoundaryKey);
    final session = await _encoderService.startEncoding(
      config: config,
      outputFileName: 'output.mp4',
    );

    try {
      final pixelRatio = await _calculatePixelRatio(
        repaintBoundaryKey: repaintBoundaryKey,
        config: config,
      );

      final frameFormat = _mapFrameFormat(config.encoding?.frameFormat);

      final frameCount = config.timeline.durationInFrames;

      // Initialize timing and diagnostics
      final totalStopwatch = Stopwatch()..start();
      int slowestFrame = 0;
      int slowestFrameTime = 0;
      FluvieLogger.box(
        'Starting frame capture',
        [
          'Total frames: $frameCount',
          'Output format: ${config.encoding?.frameFormat ?? FrameFormat.rawRgba}',
          'Pixel ratio: $pixelRatio',
          'Frame pipelining: enabled (buffer size: 5)',
        ],
        module: 'render',
        level: FluvieLogLevel.info,
      );

      // Create frame pipeline for parallel capture and encoding
      final pipeline = FramePipeline(maxBufferSize: 5);

      // Start async writer task - writes frames to FFmpeg as they become available
      final writerFuture = _startFrameWriter(pipeline, session);

      // Capture frames (producer)
      for (int frame = 0; frame < frameCount; frame++) {
        final frameStopwatch = Stopwatch()..start();

        onFrameUpdate(frame);
        await _waitForRasterization();

        // Wait for any pending async frame operations (e.g., embedded video extraction)
        if (frameReadyNotifier != null) {
          final success = await frameReadyNotifier.waitForAllFramesWithTimeout(
            const Duration(seconds: 5),
          );
          if (!success) {
            FluvieLogger.warning(
              'Frame $frame: Timeout waiting for pending operations',
              module: 'render',
            );
          }
        }

        // Use captureFrameRawExact to ensure exact dimensions for rawvideo encoding
        final bytes = await sequencer.captureFrameRawExact(
          pixelRatio: pixelRatio,
          targetWidth: config.timeline.width,
          targetHeight: config.timeline.height,
          format: frameFormat,
        );

        // Add to pipeline (may wait if buffer is full)
        await pipeline.addFrame(bytes);

        frameStopwatch.stop();
        final frameTime = frameStopwatch.elapsedMilliseconds;
        if (frameTime > slowestFrameTime) {
          slowestFrameTime = frameTime;
          slowestFrame = frame;
        }
        FluvieLogger.debug(
          'Frame ${frame + 1}/$frameCount captured (${bytes.length} bytes, ${frameTime}ms, buffer: ${pipeline.bufferedFrames})',
          module: 'render',
        );
      }

      // Close pipeline and wait for all frames to be written
      await pipeline.close();
      await writerFuture;

      // Frame capture complete
      FluvieLogger.box(
        'All frames captured',
        [
          'Total capture time: ${totalStopwatch.elapsedMilliseconds}ms',
          'Average: ${totalStopwatch.elapsedMilliseconds ~/ frameCount}ms/frame',
          'Slowest: Frame $slowestFrame (${slowestFrameTime}ms)',
        ],
        module: 'render',
        level: FluvieLogLevel.info,
      );

      FluvieLogger.debug('Closing FFmpeg session...', module: 'render');
      await session.close();
      FluvieLogger.debug(
        'Session closed, waiting for FFmpeg to complete...',
        module: 'render',
      );
      final outputPath = await session.completed;
      FluvieLogger.info(
        'Encoding complete! Output: $outputPath',
        module: 'render',
      );
      totalStopwatch.stop();
      FluvieLogger.info(
        'Total time (capture + encoding): ${totalStopwatch.elapsedMilliseconds}ms',
        module: 'render',
      );

      return outputPath;
    } catch (e) {
      await session.cancel();
      rethrow;
    }
  }

  /// Async task that writes frames from the pipeline to FFmpeg.
  Future<void> _startFrameWriter(
    FramePipeline pipeline,
    VideoEncodingSession session,
  ) async {
    await for (final bytes in pipeline.frames) {
      session.sink.add(bytes);
      pipeline.frameConsumed();
    }
  }

  Future<double> _calculatePixelRatio({
    required GlobalKey repaintBoundaryKey,
    required RenderConfig config,
  }) async {
    final context = repaintBoundaryKey.currentContext;
    if (context == null) {
      FluvieLogger.warning(
        'repaintBoundaryKey.currentContext is null, using pixel ratio 1.0',
        module: 'render',
      );
      return 1.0;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      FluvieLogger.warning(
        'renderBox is null or has no size, using pixel ratio 1.0',
        module: 'render',
      );
      return 1.0;
    }

    final widgetWidth = renderBox.size.width;
    final widgetHeight = renderBox.size.height;

    FluvieLogger.debug(
      'Widget size: ${widgetWidth}x$widgetHeight',
      module: 'render',
    );
    FluvieLogger.debug(
      'Target size: ${config.timeline.width}x${config.timeline.height}',
      module: 'render',
    );

    if (widgetWidth == 0 || widgetHeight == 0) {
      FluvieLogger.warning(
        'Widget dimension is 0, using pixel ratio 1.0',
        module: 'render',
      );
      return 1.0;
    }

    // Calculate pixel ratios for both dimensions
    final widthRatio = config.timeline.width / widgetWidth;
    final heightRatio = config.timeline.height / widgetHeight;

    // Use the larger ratio to ensure we capture at least the target resolution
    // Then we may need to crop/scale, but for rawvideo we need exact dimensions
    // For safety, use the width ratio (standard approach)
    final pixelRatio = widthRatio;

    // Verify aspect ratio matches - warn if not
    if ((widthRatio - heightRatio).abs() > 0.01) {
      FluvieLogger.warning(
        'Aspect ratio mismatch! '
        'Width ratio: $widthRatio, Height ratio: $heightRatio. '
        'Widget aspect: ${widgetWidth / widgetHeight}, '
        'Target aspect: ${config.timeline.width / config.timeline.height}. '
        'This may cause frame size issues with rawvideo encoding!',
        module: 'render',
      );
    }

    FluvieLogger.debug('Using pixel ratio: $pixelRatio', module: 'render');

    // Calculate expected output dimensions
    final expectedWidth = (widgetWidth * pixelRatio).round();
    final expectedHeight = (widgetHeight * pixelRatio).round();
    FluvieLogger.debug(
      'Expected capture size: ${expectedWidth}x$expectedHeight',
      module: 'render',
    );

    if (expectedWidth != config.timeline.width ||
        expectedHeight != config.timeline.height) {
      FluvieLogger.warning(
        'Expected capture size does not match target! '
        'Expected: ${expectedWidth}x$expectedHeight, '
        'Target: ${config.timeline.width}x${config.timeline.height}',
        module: 'render',
      );
    }

    return pixelRatio;
  }

  Future<void> _waitForRasterization() async {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    await completer.future;
  }

  ui.ImageByteFormat _mapFrameFormat(FrameFormat? format) {
    switch (format) {
      case FrameFormat.png:
        return ui.ImageByteFormat.png;
      case FrameFormat.rawRgba:
      case null:
        return ui.ImageByteFormat.rawRgba;
    }
  }
}
