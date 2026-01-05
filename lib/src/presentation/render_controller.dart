import 'package:flutter/material.dart';
import '../domain/audio_config.dart';
import '../domain/render_config.dart';
import 'render_mode_context.dart';
import 'time_consumer.dart';
import 'video_composition.dart';

/// Preview display mode for [RenderableComposition].
///
/// Controls how the composition is displayed in the preview container
/// while maintaining full resolution for frame capture.
enum PreviewMode {
  /// Scale composition to fit available space while maintaining aspect ratio.
  ///
  /// Uses [FittedBox] with [BoxFit.contain] to scale down large compositions
  /// to fit within the parent container. The composition is still captured
  /// at full resolution.
  fit,

  /// Show composition at 1:1 scale with scrolling enabled.
  ///
  /// Wraps the composition in scroll views allowing navigation when the
  /// composition is larger than the container.
  scroll,

  /// Show composition at actual size, may clip if larger than container.
  ///
  /// No scaling or scrolling is applied. The composition may be clipped
  /// if it exceeds the container bounds.
  actual,
}

/// A controller for managing video rendering state and configuration.
///
/// [RenderController] simplifies the process of rendering video compositions
/// by managing the current frame, providing the RepaintBoundary key, and
/// creating render configurations.
///
/// Example:
/// ```dart
/// final controller = RenderController();
///
/// // In your widget tree
/// RenderableComposition(
///   controller: controller,
///   composition: VideoComposition(
///     fps: 30,
///     durationInFrames: 150,
///     child: MyContent(),
///   ),
/// );
///
/// // To render
/// final config = controller.config;
/// if (config != null) {
///   await renderService.execute(
///     config: config,
///     repaintBoundaryKey: controller.boundaryKey,
///     onFrameUpdate: controller.setFrame,
///   );
/// }
/// ```
class RenderController extends ChangeNotifier {
  RenderCompositionData? _compositionData;
  int _currentFrame = 0;
  bool _isRendering = false;

  /// The GlobalKey for the RepaintBoundary wrapping the composition.
  ///
  /// Use this when calling [RenderService.execute].
  final GlobalKey boundaryKey = GlobalKey();

  /// Notifier for tracking pending frame operations during rendering.
  ///
  /// This is used by widgets like [EmbeddedVideo] to register async operations
  /// that must complete before the frame is captured.
  final FrameReadyNotifier frameReadyNotifier = FrameReadyNotifier();

  /// The current frame number being displayed/rendered.
  int get currentFrame => _currentFrame;

  /// Whether the composition is currently being rendered.
  bool get isRendering => _isRendering;

  /// Whether a composition is attached to this controller.
  bool get hasComposition => _compositionData != null;

  /// The attached composition's timeline config, if available.
  TimelineConfig? get timeline => _compositionData?.timeline;

  /// The total duration in frames, or 0 if no composition is attached.
  int get durationInFrames => _compositionData?.timeline.durationInFrames ?? 0;

  /// The frames per second, or 30 if no composition is attached.
  int get fps => _compositionData?.timeline.fps ?? 30;

  /// The render configuration for the attached composition.
  ///
  /// Returns null if no composition is attached.
  RenderConfig? get config {
    if (_compositionData == null) return null;
    return _compositionData!.toRenderConfig();
  }

  /// Attaches composition data to this controller.
  ///
  /// Called internally by [RenderableComposition].
  void attach(RenderCompositionData data) {
    _compositionData = data;
    notifyListeners();
  }

  /// Detaches the composition from this controller.
  ///
  /// Called internally when [RenderableComposition] is disposed.
  void detach() {
    _compositionData = null;
    notifyListeners();
  }

  /// Sets the current frame and notifies listeners.
  ///
  /// Use this as the `onFrameUpdate` callback when rendering:
  /// ```dart
  /// await renderService.execute(
  ///   config: config,
  ///   repaintBoundaryKey: controller.boundaryKey,
  ///   onFrameUpdate: controller.setFrame,
  /// );
  /// ```
  void setFrame(int frame) {
    if (_currentFrame != frame) {
      _currentFrame = frame;
      notifyListeners();
    }
  }

  /// Resets the frame to 0.
  void reset() {
    setFrame(0);
  }

  /// Marks the controller as rendering.
  void startRendering() {
    _isRendering = true;
    notifyListeners();
  }

  /// Marks the controller as not rendering.
  void stopRendering() {
    _isRendering = false;
    notifyListeners();
  }

  /// Gets the current progress as a value from 0.0 to 1.0.
  double get progress {
    if (durationInFrames == 0) return 0.0;
    return _currentFrame / durationInFrames;
  }
}

/// Data class holding composition configuration for rendering.
///
/// This is attached to [RenderController] when a composition is rendered.
/// Note: This is different from [VideoCompositionData] in video_composition.dart
/// which provides composition settings to descendant widgets.
class RenderCompositionData {
  /// The timeline configuration.
  final TimelineConfig timeline;

  /// The sequence configurations.
  final List<SequenceConfig> sequences;

  /// The audio track configurations.
  final List<AudioTrackConfig> audioTracks;

  /// Creates composition data.
  const RenderCompositionData({
    required this.timeline,
    this.sequences = const [],
    this.audioTracks = const [],
  });

  /// Converts this data to a [RenderConfig].
  RenderConfig toRenderConfig() {
    return RenderConfig(
      timeline: timeline,
      sequences: sequences,
      audioTracks: audioTracks,
    );
  }
}

/// A widget that wraps a [VideoComposition] and connects it to a [RenderController].
///
/// This widget:
/// - Wraps the composition in a [RepaintBoundary] for frame capture
/// - Provides a [FrameProvider] for time-based animations
/// - Automatically attaches/detaches from the controller
///
/// Example:
/// ```dart
/// final controller = RenderController();
///
/// RenderableComposition(
///   controller: controller,
///   composition: VideoComposition(
///     fps: 30,
///     durationInFrames: 150,
///     child: LayerStack(
///       children: [
///         Layer.background(child: Background()),
///         Layer(
///           startFrame: 30,
///           child: Content(),
///         ),
///       ],
///     ),
///   ),
/// );
/// ```
class RenderableComposition extends StatefulWidget {
  /// The controller managing this composition.
  final RenderController controller;

  /// The video composition to render.
  final VideoComposition composition;

  /// Optional sequences to include in the render config.
  ///
  /// If not provided, sequences are extracted from the widget tree.
  final List<SequenceConfig>? sequences;

  /// Optional audio tracks to include in the render config.
  ///
  /// If not provided, audio tracks are extracted from the widget tree.
  final List<AudioTrackConfig>? audioTracks;

  /// How the composition is displayed in the preview container.
  ///
  /// Controls scaling behavior when the composition dimensions differ
  /// from the available display area. The composition is always captured
  /// at full resolution regardless of this setting.
  ///
  /// Defaults to `PreviewMode.fit` which scales the composition to fit
  /// within the available space.
  final PreviewMode previewMode;

  /// Creates a renderable composition.
  const RenderableComposition({
    super.key,
    required this.controller,
    required this.composition,
    this.sequences,
    this.audioTracks,
    this.previewMode = PreviewMode.fit,
  });

  @override
  State<RenderableComposition> createState() => _RenderableCompositionState();
}

class _RenderableCompositionState extends State<RenderableComposition> {
  @override
  void initState() {
    super.initState();
    _attachController();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(RenderableComposition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
      _attachController();
    } else if (oldWidget.composition != widget.composition) {
      _attachController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    widget.controller.detach();
    super.dispose();
  }

  void _attachController() {
    final comp = widget.composition;
    widget.controller.attach(
      RenderCompositionData(
        timeline: TimelineConfig(
          fps: comp.fps,
          durationInFrames: comp.durationInFrames,
          width: comp.width,
          height: comp.height,
        ),
        sequences: widget.sequences ?? [],
        audioTracks: widget.audioTracks ?? [],
      ),
    );
  }

  void _onControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // The core content: RepaintBoundary at full resolution for frame capture
    final content = RepaintBoundary(
      key: widget.controller.boundaryKey,
      child: SizedBox(
        width: widget.composition.width.toDouble(),
        height: widget.composition.height.toDouble(),
        child: RenderModeProvider(
          isRendering: widget.controller.isRendering,
          frameReadyNotifier: widget.controller.frameReadyNotifier,
          child: FrameProvider(
            frame: widget.controller.currentFrame,
            child: widget.composition,
          ),
        ),
      ),
    );

    // Wrap based on preview mode
    switch (widget.previewMode) {
      case PreviewMode.fit:
        // Scale to fit available space while maintaining aspect ratio
        return FittedBox(fit: BoxFit.contain, child: content);
      case PreviewMode.scroll:
        // Allow scrolling in both directions for large compositions
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: content,
          ),
        );
      case PreviewMode.actual:
        // Show at actual size, may clip
        return content;
    }
  }
}
