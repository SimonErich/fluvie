import 'package:flutter/material.dart';
import '../declarative/core/video.dart';
import 'time_consumer.dart';

/// Controller for [VideoPreview] widget.
///
/// Allows external control of playback state and provides current frame info.
///
/// Example:
/// ```dart
/// final controller = VideoPreviewController();
///
/// // Control playback
/// controller.play();
/// controller.pause();
/// controller.seekTo(60);
///
/// // Listen to changes
/// controller.addListener(() {
///   print('Frame: ${controller.currentFrame}');
/// });
/// ```
class VideoPreviewController extends ChangeNotifier {
  int _currentFrame = 0;
  int _totalFrames = 0;
  bool _isPlaying = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;

  // Internal animation controller binding
  AnimationController? _animationController;
  bool _loop = true;

  /// Current frame number (0-indexed).
  int get currentFrame => _currentFrame;

  /// Total number of frames in the video.
  int get totalFrames => _totalFrames;

  /// Whether the preview is currently playing.
  bool get isPlaying => _isPlaying;

  /// Whether an export is in progress.
  bool get isExporting => _isExporting;

  /// Export progress as a value from 0.0 to 1.0.
  double get exportProgress => _exportProgress;

  /// Current progress as a value from 0.0 to 1.0.
  double get progress => _totalFrames > 0 ? _currentFrame / _totalFrames : 0.0;

  /// Binds this controller to an AnimationController.
  ///
  /// Called internally by [VideoPreview].
  void _bind(AnimationController controller, int totalFrames, bool loop) {
    _animationController = controller;
    _totalFrames = totalFrames;
    _loop = loop;
    notifyListeners();
  }

  /// Unbinds the animation controller.
  ///
  /// Called internally when [VideoPreview] is disposed.
  void _unbind() {
    _animationController = null;
  }

  /// Updates the current frame.
  ///
  /// Called internally by [VideoPreview].
  void _updateFrame(int frame) {
    if (_currentFrame != frame) {
      _currentFrame = frame;
      notifyListeners();
    }
  }

  /// Updates the playing state.
  ///
  /// Called internally by [VideoPreview].
  void _updatePlayingState(bool playing) {
    if (_isPlaying != playing) {
      _isPlaying = playing;
      notifyListeners();
    }
  }

  /// Sets the exporting state.
  ///
  /// Called internally during export.
  void _setExporting(bool exporting) {
    _isExporting = exporting;
    if (!exporting) {
      _exportProgress = 0.0;
    }
    notifyListeners();
  }

  /// Updates export progress.
  ///
  /// Called internally during export.
  void _updateExportProgress(double progress) {
    _exportProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Start or resume playback.
  void play() {
    final controller = _animationController;
    if (controller == null) return;

    if (_loop) {
      controller.repeat();
    } else {
      controller.forward();
    }
    _updatePlayingState(true);
  }

  /// Pause playback.
  void pause() {
    _animationController?.stop();
    _updatePlayingState(false);
  }

  /// Toggle between play and pause.
  void toggle() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Seek to a specific frame.
  void seekTo(int frame) {
    final controller = _animationController;
    if (controller == null || _totalFrames == 0) return;

    final clampedFrame = frame.clamp(0, _totalFrames - 1);
    final value = clampedFrame / _totalFrames;
    controller.value = value;
    _updateFrame(clampedFrame);
  }

  /// Seek to the beginning.
  void seekToStart() {
    seekTo(0);
  }

  /// Seek to the end.
  void seekToEnd() {
    seekTo(_totalFrames - 1);
  }

  /// Step forward one frame.
  void stepForward() {
    seekTo(_currentFrame + 1);
  }

  /// Step backward one frame.
  void stepBackward() {
    seekTo(_currentFrame - 1);
  }
}

/// A widget that provides an animated preview of a [Video] composition.
///
/// [VideoPreview] handles all the boilerplate required to preview a Fluvie video:
/// - AnimationController lifecycle management
/// - FrameProvider integration
/// - Aspect ratio preservation
/// - Optional playback controls
///
/// Example:
/// ```dart
/// VideoPreview(
///   video: MyVideo(),
///   autoPlay: true,
///   showControls: true,
///   showExportButton: true,
/// )
/// ```
///
/// For external control of playback:
/// ```dart
/// final controller = VideoPreviewController();
///
/// VideoPreview(
///   video: MyVideo(),
///   controller: controller,
/// )
///
/// // Later...
/// controller.play();
/// controller.pause();
/// controller.seekTo(60);
/// ```
class VideoPreview extends StatefulWidget {
  /// The [Video] widget to preview.
  final Video video;

  /// Whether to automatically start playback when mounted.
  ///
  /// Defaults to `true`.
  final bool autoPlay;

  /// Whether to loop the video when it reaches the end.
  ///
  /// Defaults to `true`.
  final bool loop;

  /// Whether to show playback controls (play/pause, scrubber).
  ///
  /// Defaults to `false` for embedding in other layouts.
  final bool showControls;

  /// Whether to show a download/export button.
  ///
  /// When tapped, triggers [onExport] callback if provided,
  /// otherwise uses the default [VideoExporter].
  ///
  /// Defaults to `false`.
  final bool showExportButton;

  /// Callback when export button is pressed.
  ///
  /// If `null` and [showExportButton] is `true`, a default export
  /// using [VideoExporter] is triggered.
  final VoidCallback? onExport;

  /// Callback fired on each frame update.
  ///
  /// Useful for synchronizing external UI with playback.
  final void Function(int frame, int totalFrames)? onFrameUpdate;

  /// Callback when playback completes.
  ///
  /// Called before looping if [loop] is `true`.
  final VoidCallback? onComplete;

  /// How to fit the video within the available space.
  ///
  /// Defaults to [BoxFit.contain].
  final BoxFit fit;

  /// Background color shown around the video when aspect ratio differs.
  ///
  /// Defaults to [Colors.black].
  final Color backgroundColor;

  /// Optional controller for external control of playback.
  ///
  /// If not provided, an internal controller is created and managed.
  final VideoPreviewController? controller;

  /// Style configuration for the controls.
  ///
  /// If `null`, uses default styling.
  final VideoPreviewControlsStyle? controlsStyle;

  /// Creates a video preview widget.
  const VideoPreview({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.loop = true,
    this.showControls = false,
    this.showExportButton = false,
    this.onExport,
    this.onFrameUpdate,
    this.onComplete,
    this.fit = BoxFit.contain,
    this.backgroundColor = Colors.black,
    this.controller,
    this.controlsStyle,
  });

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview>
    with SingleTickerProviderStateMixin {
  late VideoPreviewController _controller;
  late AnimationController _animationController;
  bool _ownsController = false;

  int get _totalFrames => widget.video.totalDuration;
  int get _fps => widget.video.fps;
  Duration get _duration =>
      Duration(milliseconds: (_totalFrames / _fps * 1000).round());

  @override
  void initState() {
    super.initState();

    // Use provided controller or create one
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = VideoPreviewController();
      _ownsController = true;
    }

    // Create animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: _duration,
    );

    // Connect animation to frame updates
    _animationController.addListener(_onAnimationTick);
    _animationController.addStatusListener(_onAnimationStatus);

    // Bind controller
    _controller._bind(_animationController, _totalFrames, widget.loop);

    // Auto-play if requested
    if (widget.autoPlay) {
      // Use post-frame callback to ensure widget is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.autoPlay) {
          _controller.play();
        }
      });
    }
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle controller changes
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      if (widget.controller != null) {
        _controller = widget.controller!;
        _ownsController = false;
      } else {
        _controller = VideoPreviewController();
        _ownsController = true;
      }
      _controller._bind(_animationController, _totalFrames, widget.loop);
    }

    // Handle video changes (duration might change)
    if (widget.video != oldWidget.video) {
      final newDuration = _duration;
      if (_animationController.duration != newDuration) {
        final wasPlaying = _controller.isPlaying;
        final currentProgress = _animationController.value;

        _animationController.duration = newDuration;
        _controller._bind(_animationController, _totalFrames, widget.loop);

        if (wasPlaying) {
          _animationController.value = currentProgress;
          _controller.play();
        }
      }
    }
  }

  void _onAnimationTick() {
    final newFrame = (_animationController.value * _totalFrames).floor().clamp(
      0,
      _totalFrames > 0 ? _totalFrames - 1 : 0,
    );

    if (newFrame != _controller._currentFrame) {
      _controller._updateFrame(newFrame);
      widget.onFrameUpdate?.call(newFrame, _totalFrames);
      if (mounted) setState(() {});
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    final isPlaying =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;

    if (status == AnimationStatus.completed) {
      widget.onComplete?.call();
      if (widget.loop) {
        _animationController.forward(from: 0.0);
      } else {
        _controller._updatePlayingState(false);
      }
    } else {
      _controller._updatePlayingState(isPlaying);
    }
  }

  @override
  void dispose() {
    _animationController.removeListener(_onAnimationTick);
    _animationController.removeStatusListener(_onAnimationStatus);
    _animationController.dispose();
    _controller._unbind();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Column(
        children: [
          Expanded(child: _buildVideoPreview()),
          if (widget.showControls || widget.showExportButton)
            _VideoPreviewControls(
              controller: _controller,
              fps: _fps,
              showPlayPause: widget.showControls,
              showScrubber: widget.showControls,
              showFrameCounter: widget.showControls,
              showExportButton: widget.showExportButton,
              onExport: widget.onExport,
              style: widget.controlsStyle ?? const VideoPreviewControlsStyle(),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    Widget content = SizedBox(
      width: widget.video.width.toDouble(),
      height: widget.video.height.toDouble(),
      child: FrameProvider(
        frame: _controller.currentFrame,
        child: widget.video,
      ),
    );

    // Apply fitting
    switch (widget.fit) {
      case BoxFit.contain:
        return FittedBox(fit: BoxFit.contain, child: content);
      case BoxFit.cover:
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: content,
        );
      case BoxFit.fill:
        return FittedBox(fit: BoxFit.fill, child: content);
      case BoxFit.none:
        return Center(child: content);
      default:
        return FittedBox(fit: widget.fit, child: content);
    }
  }
}

/// Style configuration for [VideoPreview] controls.
class VideoPreviewControlsStyle {
  /// Background color of the controls bar.
  final Color backgroundColor;

  /// Icon color for control buttons.
  final Color iconColor;

  /// Active color for scrubber and progress.
  final Color activeColor;

  /// Inactive color for scrubber track.
  final Color inactiveColor;

  /// Text style for frame counter.
  final TextStyle? textStyle;

  /// Height of the controls bar.
  final double height;

  /// Padding around controls.
  final EdgeInsets padding;

  /// Creates a controls style configuration.
  const VideoPreviewControlsStyle({
    this.backgroundColor = const Color(0xCC000000),
    this.iconColor = Colors.white,
    this.activeColor = const Color(0xFF6366F1),
    this.inactiveColor = const Color(0x4DFFFFFF),
    this.textStyle,
    this.height = 56,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });
}

/// Internal controls widget for VideoPreview.
class _VideoPreviewControls extends StatelessWidget {
  final VideoPreviewController controller;
  final int fps;
  final bool showPlayPause;
  final bool showScrubber;
  final bool showFrameCounter;
  final bool showExportButton;
  final VoidCallback? onExport;
  final VideoPreviewControlsStyle style;

  const _VideoPreviewControls({
    required this.controller,
    required this.fps,
    required this.showPlayPause,
    required this.showScrubber,
    required this.showFrameCounter,
    required this.showExportButton,
    required this.onExport,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          height: style.height,
          padding: style.padding,
          decoration: BoxDecoration(color: style.backgroundColor),
          child: Row(
            children: [
              // Play/Pause button
              if (showPlayPause) ...[
                _buildPlayPauseButton(),
                const SizedBox(width: 8),
              ],

              // Scrubber
              if (showScrubber) Expanded(child: _buildScrubber()),

              // Frame counter
              if (showFrameCounter) ...[
                const SizedBox(width: 12),
                _buildFrameCounter(),
              ],

              // Export button
              if (showExportButton) ...[
                const SizedBox(width: 8),
                _buildExportButton(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayPauseButton() {
    return IconButton(
      icon: Icon(
        controller.isPlaying ? Icons.pause : Icons.play_arrow,
        color: style.iconColor,
      ),
      onPressed: controller.toggle,
      tooltip: controller.isPlaying ? 'Pause' : 'Play',
    );
  }

  Widget _buildScrubber() {
    final value = controller.totalFrames > 0
        ? controller.currentFrame / controller.totalFrames
        : 0.0;

    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: style.activeColor,
        inactiveTrackColor: style.inactiveColor,
        thumbColor: style.activeColor,
        overlayColor: style.activeColor.withValues(alpha: 0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: value.clamp(0.0, 1.0),
        onChanged: (newValue) {
          final frame = (newValue * controller.totalFrames).round();
          controller.seekTo(frame);
        },
        onChangeStart: (_) {
          // Pause during scrubbing for smoother experience
          if (controller.isPlaying) {
            controller.pause();
          }
        },
      ),
    );
  }

  Widget _buildFrameCounter() {
    final current = controller.currentFrame;
    final total = controller.totalFrames;
    final currentSeconds = (current / fps).toStringAsFixed(1);
    final totalSeconds = (total / fps).toStringAsFixed(1);

    return Text(
      '${currentSeconds}s / ${totalSeconds}s',
      style:
          style.textStyle ??
          TextStyle(
            color: style.iconColor.withValues(alpha: 0.8),
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }

  Widget _buildExportButton() {
    if (controller.isExporting) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: controller.exportProgress,
              strokeWidth: 2,
              color: style.activeColor,
            ),
            Text(
              '${(controller.exportProgress * 100).toInt()}%',
              style: TextStyle(
                color: style.iconColor,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return IconButton(
      icon: Icon(Icons.download, color: style.iconColor),
      onPressed: onExport,
      tooltip: 'Export video',
    );
  }
}
