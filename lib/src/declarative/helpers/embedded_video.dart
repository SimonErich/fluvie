import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/audio_config.dart';
import '../../domain/embedded_video_config.dart';
import '../../presentation/render_mode_context.dart';
import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../utils/logger.dart';
import '../core/scene.dart';
import 'embedded_video_controller.dart';

/// A widget that displays video frames synchronized with the composition timeline.
///
/// [EmbeddedVideo] extracts frames from a video file and displays them
/// in sync with the current composition frame. This allows embedding
/// external videos within a Fluvie composition.
///
/// The video frames are extracted using FFmpeg and cached for smooth playback.
/// Background preloading ensures frames are ready ahead of playback.
///
/// ## Audio Synchronization
///
/// By default, audio from the embedded video is included in the final render.
/// Use [includeAudio], [audioVolume], [audioFadeInFrames], and [audioFadeOutFrames]
/// to control audio behavior.
///
/// ## Duration
///
/// If [durationInFrames] is not specified, it is automatically calculated
/// from the source video's duration minus [trimStart].
///
/// Example:
/// ```dart
/// EmbeddedVideo(
///   assetPath: 'assets/highlight.mp4',
///   width: 900,
///   height: 500,
///   startFrame: 40,  // Start showing at frame 40
///   trimStart: Duration(seconds: 2),  // Skip first 2 seconds of source
///   fit: BoxFit.cover,
///   includeAudio: true,
///   audioVolume: 0.8,
/// )
/// ```
class EmbeddedVideo extends StatefulWidget {
  /// Path to the video asset.
  ///
  /// Can be an asset path, file path, or URL.
  final String assetPath;

  /// Width of the video display.
  final double? width;

  /// Height of the video display.
  final double? height;

  /// Frame at which to start showing the video in the composition.
  final int startFrame;

  /// Duration to trim from the start of the source video.
  final Duration trimStart;

  /// Duration in composition frames.
  ///
  /// If null, automatically calculated from source video duration.
  final int? durationInFrames;

  /// How to fit the video within the bounds.
  final BoxFit fit;

  /// Border radius for the video container.
  final BorderRadius? borderRadius;

  /// Decoration for the video container.
  final BoxDecoration? decoration;

  /// Placeholder widget shown while loading or before video starts.
  final Widget? placeholder;

  /// Widget shown when an error occurs.
  final Widget? errorWidget;

  /// Whether to include audio from this video in the final render.
  final bool includeAudio;

  /// Audio volume (0.0 to 1.0).
  final double audioVolume;

  /// Audio fade-in duration in frames.
  final int audioFadeInFrames;

  /// Audio fade-out duration in frames.
  final int audioFadeOutFrames;

  /// Number of frames to preload ahead.
  final int preloadFrames;

  /// Unique identifier for this embedded video.
  ///
  /// Used internally for generating unique filter labels.
  /// If not provided, a unique ID is generated.
  final String? id;

  /// Creates an embedded video widget.
  const EmbeddedVideo({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.startFrame = 0,
    this.trimStart = Duration.zero,
    this.durationInFrames,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.decoration,
    this.placeholder,
    this.errorWidget,
    this.includeAudio = true,
    this.audioVolume = 1.0,
    this.audioFadeInFrames = 0,
    this.audioFadeOutFrames = 0,
    this.preloadFrames = 30,
    this.id,
  });

  @override
  State<EmbeddedVideo> createState() => _EmbeddedVideoState();
}

class _EmbeddedVideoState extends State<EmbeddedVideo> {
  late EmbeddedVideoController _controller;
  bool _initialized = false;
  String _uniqueId = '';
  int _globalStartFrame = 0; // The actual global start frame in composition

  // Last-frame retention to avoid placeholder flashes
  ui.Image? _lastSuccessfulFrame;

  @override
  void initState() {
    super.initState();
    _uniqueId = widget.id ?? 'embedded_video_$hashCode';
    // Controller will be created in didChangeDependencies when we have context
  }

  void _createController() {
    _controller = EmbeddedVideoController(
      videoPath: widget.assetPath,
      startFrame: _globalStartFrame, // Use calculated global start frame
      trimStart: widget.trimStart,
      durationInFrames: widget.durationInFrames,
      includeAudio: widget.includeAudio,
      audioVolume: widget.audioVolume,
      audioFadeInFrames: widget.audioFadeInFrames,
      audioFadeOutFrames: widget.audioFadeOutFrames,
      preloadFrames: widget.preloadFrames,
      fit: widget.fit,
    );
    _controller.addListener(_onControllerUpdate);
  }

  /// Calculates the global start frame by combining scene start + local start.
  int _calculateGlobalStartFrame(BuildContext context) {
    final sceneContext = SceneContext.of(context);
    if (sceneContext != null) {
      // Scene-relative: add scene's global start to widget's local start
      return sceneContext.sceneStartFrame + widget.startFrame;
    }
    // No scene context - use widget's startFrame directly (might be global)
    return widget.startFrame;
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // Calculate global start frame from scene context
      _globalStartFrame = _calculateGlobalStartFrame(context);
      FluvieLogger.debug(
        'Global start frame = $_globalStartFrame (scene start + local ${widget.startFrame})',
        module: 'embedded',
      );

      // Now create the controller with the correct global start frame
      _createController();
      _initializeController();
    }
  }

  Future<void> _initializeController() async {
    final composition = VideoComposition.of(context);
    if (composition == null) {
      FluvieLogger.warning(
        'VideoComposition.of(context) returned null!',
        module: 'embedded',
      );
      // Try to initialize with a default FPS
      _initialized = true;
      await _controller.initialize(30);
      return;
    }
    FluvieLogger.debug(
      'Found composition with fps=${composition.fps}',
      module: 'embedded',
    );
    _initialized = true;
    await _controller.initialize(composition.fps);
  }

  @override
  void didUpdateWidget(EmbeddedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if we need to recreate the controller
    if (widget.assetPath != oldWidget.assetPath ||
        widget.startFrame != oldWidget.startFrame ||
        widget.trimStart != oldWidget.trimStart ||
        widget.durationInFrames != oldWidget.durationInFrames) {
      _controller.removeListener(_onControllerUpdate);
      _controller.dispose();
      // Recalculate global start frame
      _globalStartFrame = _calculateGlobalStartFrame(context);
      _createController();
      _initialized = false;
      _initializeController();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    // Clear retained frame reference
    _lastSuccessfulFrame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Not yet initialized - show loading placeholder
    if (!_initialized) {
      return _buildLoadingPlaceholder();
    }

    return TimeConsumer(
      builder: (context, frame, _) {
        // Check controller state
        if (_controller.state == ExtractionState.error) {
          return widget.errorWidget ?? _buildErrorContent();
        }

        if (_controller.state == ExtractionState.loading ||
            _controller.state == ExtractionState.uninitialized) {
          return _buildLoadingPlaceholder();
        }

        // Check if video is in range using global frame calculation
        // The controller uses global startFrame, so isFrameInRange compares correctly
        if (!_controller.isFrameInRange(frame)) {
          // Before or after this video's display window - clear retained frame and show placeholder
          _lastSuccessfulFrame = null;

          // Trigger lookahead preloading when approaching the start frame
          _controller.onApproachingStart(frame);

          return _buildPlaceholder();
        }

        // Display the video frame
        return _buildVideoFrame(frame);
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration:
          widget.decoration ??
          BoxDecoration(color: Colors.black, borderRadius: widget.borderRadius),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
        ),
      ),
    );
  }

  Widget _buildVideoFrame(int frame) {
    final displayWidth = widget.width?.toInt() ?? 640;
    final displayHeight = widget.height?.toInt() ?? 360;

    // Check if we're in render mode
    final renderMode = RenderModeProvider.of(context);
    final isRendering = renderMode?.isRendering ?? false;
    final frameNotifier = renderMode?.frameReadyNotifier;

    // In render mode, register a pending frame operation
    Completer<void>? pendingFrame;
    if (isRendering && frameNotifier != null) {
      pendingFrame = frameNotifier.registerPendingFrame();
    }

    return FutureBuilder<ui.Image?>(
      future: _controller.getFrame(frame, displayWidth, displayHeight),
      builder: (context, snapshot) {
        Widget content;

        if (snapshot.hasData && snapshot.data != null) {
          // Store successful frame for retention
          _lastSuccessfulFrame = snapshot.data;

          // Mark frame as ready in render mode
          if (pendingFrame != null && frameNotifier != null) {
            frameNotifier.markFrameReady(pendingFrame);
          }

          // Display actual video frame
          content = RawImage(
            image: snapshot.data,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
          );
        } else if (snapshot.hasError) {
          // Mark frame as failed in render mode
          if (pendingFrame != null && frameNotifier != null) {
            frameNotifier.markFrameFailed(pendingFrame, snapshot.error!);
          }

          // Show error state
          content = _buildErrorContent();
        } else if (_lastSuccessfulFrame != null) {
          // Loading state - show last successful frame instead of loading indicator
          // This prevents placeholder flashing between frames
          // Note: In render mode, we're still waiting for the new frame
          content = RawImage(
            image: _lastSuccessfulFrame,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
          );
        } else {
          // No previous frame available - show loading content
          content = _buildLoadingContent();
        }

        // Apply container decoration
        Widget result = Container(
          width: widget.width,
          height: widget.height,
          decoration:
              widget.decoration ??
              BoxDecoration(
                color: Colors.black,
                borderRadius: widget.borderRadius,
              ),
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            child: content,
          ),
        );

        return result;
      },
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration:
          widget.decoration ??
          BoxDecoration(
            color: Colors.grey[900],
            borderRadius: widget.borderRadius,
          ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              'Video Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_controller.error != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _controller.error!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration:
          widget.decoration ??
          BoxDecoration(
            color: Colors.grey[900],
            borderRadius: widget.borderRadius,
          ),
      child: Center(
        child:
            widget.placeholder ??
            Icon(
              Icons.play_circle_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
      ),
    );
  }

  // --- Configuration Methods for Encoding ---

  /// Returns the video configuration for encoding.
  ///
  /// This is used by RenderService to collect embedded video configs.
  /// Uses the global start frame (scene start + local start) for proper timing.
  EmbeddedVideoConfig toVideoConfig(BuildContext context) {
    // Calculate duration - prefer controller's calculated value, then explicit, then scene-based fallback
    int duration =
        _controller.calculatedDurationInFrames ?? widget.durationInFrames ?? 0;

    // Fallback: calculate from scene context if duration is still 0
    if (duration <= 0) {
      final sceneContext = SceneContext.of(context);
      if (sceneContext != null) {
        // Available frames = scene length - local start frame
        duration = sceneContext.sceneDurationInFrames - widget.startFrame;
        if (duration < 0) duration = 0;
      }
    }

    // Log configuration details
    FluvieLogger.section('EmbeddedVideo.toVideoConfig()', [
      'assetPath: ${widget.assetPath}',
      'widget.startFrame: ${widget.startFrame}',
      'widget.durationInFrames: ${widget.durationInFrames}',
      'widget.includeAudio: ${widget.includeAudio}',
      'widget.audioVolume: ${widget.audioVolume}',
      '_globalStartFrame: $_globalStartFrame',
      '_controller.state: ${_controller.state}',
      '_controller.calculatedDurationInFrames: ${_controller.calculatedDurationInFrames}',
      'FINAL duration: $duration',
      'Audio will be processed: ${widget.includeAudio && duration > 0 ? 'YES' : 'NO'}',
    ], module: 'embedded');

    return EmbeddedVideoConfig(
      videoPath: widget.assetPath,
      startFrame: _globalStartFrame, // Use global frame for FFmpeg timing
      durationInFrames: duration,
      trimStartSeconds: widget.trimStart.inMicroseconds / 1000000.0,
      width: widget.width?.toInt() ?? 640,
      height: widget.height?.toInt() ?? 360,
      positionX: 0, // Position is handled by parent widgets
      positionY: 0,
      includeAudio: widget.includeAudio,
      audioVolume: widget.audioVolume,
      audioFadeInFrames: widget.audioFadeInFrames,
      audioFadeOutFrames: widget.audioFadeOutFrames,
      id: _uniqueId,
    );
  }

  /// Returns the audio configuration for encoding.
  ///
  /// Returns null if [includeAudio] is false or video has no audio.
  AudioTrackConfig? toAudioConfig(BuildContext context) {
    if (!widget.includeAudio) {
      return null;
    }

    return _controller.toAudioConfig();
  }
}
