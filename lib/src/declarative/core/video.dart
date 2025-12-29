import 'package:flutter/widgets.dart';
import '../../domain/embedded_video_config.dart';
import '../../domain/render_config.dart';
import '../../presentation/audio_source.dart';
import '../../presentation/background_audio.dart';
import '../../presentation/video_composition.dart';
import '../../presentation/time_consumer.dart';
import '../../presentation/layer.dart';
import '../../presentation/layer_stack.dart';
import '../../utils/logger.dart';
import '../helpers/embedded_video.dart';
import 'scene.dart';
import 'scene_transition.dart';

/// The root widget for declarative video composition.
///
/// [Video] defines a complete video with scenes, background music,
/// and global settings. It automatically calculates total duration
/// from scenes and handles scene transitions.
///
/// Example:
/// ```dart
/// Video(
///   fps: 30,
///   width: 1080,
///   height: 1920,
///   defaultTransition: SceneTransition.crossFade(durationInFrames: 15),
///   scenes: [
///     Scene(
///       durationInFrames: 120,
///       background: Background.solid(Colors.blue),
///       children: [
///         AnimatedText('Scene 1'),
///       ],
///     ),
///     Scene(
///       durationInFrames: 90,
///       background: Background.solid(Colors.red),
///       children: [
///         AnimatedText('Scene 2'),
///       ],
///     ),
///   ],
/// )
/// ```
class Video extends StatelessWidget {
  /// Frames per second.
  final int fps;

  /// Width of the video in pixels.
  final int width;

  /// Height of the video in pixels.
  final int height;

  /// The scenes in this video.
  final List<Scene> scenes;

  /// Default transition applied between all scenes.
  ///
  /// Individual scenes can override this with their own transitions.
  final SceneTransition? defaultTransition;

  /// Background music asset path.
  final String? backgroundMusicAsset;

  /// Background music volume (0.0 to 1.0).
  final double musicVolume;

  /// Frames to fade in background music.
  final int musicFadeInFrames;

  /// Frames to fade out background music.
  final int musicFadeOutFrames;

  /// Encoding configuration for the video output.
  ///
  /// Use this to configure quality, frame format, and other encoding options.
  /// For example, to enable PNG frame format for transparency support:
  /// ```dart
  /// Video(
  ///   encoding: EncodingConfig(frameFormat: FrameFormat.png),
  ///   // ...
  /// )
  /// ```
  final EncodingConfig? encoding;

  /// Creates a video composition.
  const Video({
    super.key,
    this.fps = 30,
    this.width = 1080,
    this.height = 1920,
    required this.scenes,
    this.defaultTransition,
    this.backgroundMusicAsset,
    this.musicVolume = 1.0,
    this.musicFadeInFrames = 30,
    this.musicFadeOutFrames = 30,
    this.encoding,
  });

  /// Calculates the total duration of all scenes in frames.
  int get totalDuration {
    int duration = 0;
    for (final scene in scenes) {
      duration += scene.durationInFrames;
    }
    return duration;
  }

  /// Calculates the start frame for a scene at the given index.
  int startFrameForScene(int index) {
    int frame = 0;
    for (int i = 0; i < index && i < scenes.length; i++) {
      frame += scenes[i].durationInFrames;
    }
    return frame;
  }

  /// Returns the render configuration for this video.
  ///
  /// This is used by the example gallery and render service.
  RenderConfig toConfig() {
    return RenderConfig(
      timeline: TimelineConfig(
        fps: fps,
        durationInFrames: totalDuration,
        width: width,
        height: height,
      ),
      sequences: [], // Populated by RenderService
      encoding: encoding,
    );
  }

  /// Extracts all [EmbeddedVideo] configurations from all scenes.
  ///
  /// This traverses the widget tree at construction time to find all
  /// EmbeddedVideo widgets, regardless of whether they would be visible
  /// at the current frame.
  List<EmbeddedVideoConfig> extractEmbeddedVideoConfigs() {
    final configs = <EmbeddedVideoConfig>[];

    for (int i = 0; i < scenes.length; i++) {
      final scene = scenes[i];
      final sceneStartFrame = startFrameForScene(i);

      // Recursively find EmbeddedVideo widgets in scene children
      _findEmbeddedVideosInWidgets(
        scene.children,
        sceneStartFrame,
        scene.durationInFrames,
        configs,
      );
    }

    // Log extracted configs
    final logLines = <String>[
      'Total scenes: ${scenes.length}',
      'EmbeddedVideos found: ${configs.length}',
    ];
    for (var i = 0; i < configs.length; i++) {
      final c = configs[i];
      logLines.add('  [$i] ${c.videoPath}');
      logLines.add(
        '      startFrame=${c.startFrame}, duration=${c.durationInFrames}',
      );
      logLines.add(
        '      includeAudio=${c.includeAudio}, volume=${c.audioVolume}',
      );
    }
    FluvieLogger.section(
      'Video.extractEmbeddedVideoConfigs()',
      logLines,
      module: 'video',
    );

    return configs;
  }

  /// Recursively finds EmbeddedVideo widgets in a list of widgets.
  void _findEmbeddedVideosInWidgets(
    List<Widget> widgets,
    int sceneStartFrame,
    int sceneLength,
    List<EmbeddedVideoConfig> configs,
  ) {
    for (final widget in widgets) {
      if (widget is EmbeddedVideo) {
        // Calculate global start frame
        final globalStartFrame = sceneStartFrame + widget.startFrame;

        // Calculate duration - use explicit if provided, else scene-based
        int duration =
            widget.durationInFrames ?? (sceneLength - widget.startFrame);
        if (duration < 0) duration = 0;

        final config = EmbeddedVideoConfig(
          videoPath: widget.assetPath,
          startFrame: globalStartFrame,
          durationInFrames: duration,
          trimStartSeconds: widget.trimStart.inMicroseconds / 1000000.0,
          width: widget.width?.toInt() ?? 640,
          height: widget.height?.toInt() ?? 360,
          positionX: 0,
          positionY: 0,
          includeAudio: widget.includeAudio,
          audioVolume: widget.audioVolume,
          audioFadeInFrames: widget.audioFadeInFrames,
          audioFadeOutFrames: widget.audioFadeOutFrames,
          id: 'embedded_video_${configs.length}',
        );

        configs.add(config);
      }

      // Check for nested widgets in common container types
      _findEmbeddedVideosInWidget(
        widget,
        sceneStartFrame,
        sceneLength,
        configs,
      );
    }
  }

  /// Recursively searches a single widget for EmbeddedVideo children.
  void _findEmbeddedVideosInWidget(
    Widget widget,
    int sceneStartFrame,
    int sceneLength,
    List<EmbeddedVideoConfig> configs,
  ) {
    // Handle common container widgets that have children
    if (widget is MultiChildRenderObjectWidget) {
      _findEmbeddedVideosInWidgets(
        widget.children,
        sceneStartFrame,
        sceneLength,
        configs,
      );
    } else if (widget is SingleChildRenderObjectWidget &&
        widget.child != null) {
      _findEmbeddedVideosInWidgets(
        [widget.child!],
        sceneStartFrame,
        sceneLength,
        configs,
      );
    } else if (widget is ProxyWidget) {
      _findEmbeddedVideosInWidgets(
        [widget.child],
        sceneStartFrame,
        sceneLength,
        configs,
      );
    }
    // Check common Flutter container types
    else if (widget is Container && widget.child != null) {
      _findEmbeddedVideosInWidgets(
        [widget.child!],
        sceneStartFrame,
        sceneLength,
        configs,
      );
    } else if (widget is DecoratedBox && widget.child != null) {
      _findEmbeddedVideosInWidgets(
        [widget.child!],
        sceneStartFrame,
        sceneLength,
        configs,
      );
    }
    // For any other widget, try to access 'child' or 'children' properties dynamically
    // This handles custom StatelessWidget subclasses like VPositioned, AnimatedProp, etc.
    else {
      _tryExtractChildFromWidget(widget, sceneStartFrame, sceneLength, configs);
    }
  }

  /// Tries to extract child widgets from a widget using dynamic property access.
  ///
  /// This handles custom widgets that have 'child' or 'children' properties
  /// but aren't standard Flutter widget types.
  void _tryExtractChildFromWidget(
    Widget widget,
    int sceneStartFrame,
    int sceneLength,
    List<EmbeddedVideoConfig> configs,
  ) {
    try {
      // Try to access 'child' property dynamically
      final dynamic widgetDynamic = widget;

      // Check for 'child' property
      try {
        final child = widgetDynamic.child;
        if (child is Widget) {
          _findEmbeddedVideosInWidgets(
            [child],
            sceneStartFrame,
            sceneLength,
            configs,
          );
          return;
        }
      } catch (_) {
        // Widget doesn't have a 'child' property
      }

      // Check for 'children' property
      try {
        final children = widgetDynamic.children;
        if (children is List<Widget>) {
          _findEmbeddedVideosInWidgets(
            children,
            sceneStartFrame,
            sceneLength,
            configs,
          );
          return;
        }
      } catch (_) {
        // Widget doesn't have a 'children' property
      }
    } catch (_) {
      // Ignore any errors in dynamic access
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build scene layers with timing
    final List<Widget> sceneLayers = [];

    for (int i = 0; i < scenes.length; i++) {
      final scene = scenes[i];
      final startFrame = startFrameForScene(i);
      final endFrame = startFrame + scene.durationInFrames;

      // Get transitions
      final transitionIn =
          scene.transitionIn ?? (i > 0 ? defaultTransition : null);
      final transitionOut =
          scene.transitionOut ??
          (i < scenes.length - 1 ? defaultTransition : null);

      // Calculate fade frames from transitions
      final fadeIn = transitionIn?.durationInFrames ?? scene.fadeInFrames;
      final fadeOut = transitionOut?.durationInFrames ?? scene.fadeOutFrames;

      // Build scene with transition wrapper
      Widget sceneWidget = scene;

      // Apply entry animation if transition specified
      if (transitionIn != null &&
          transitionIn.type != SceneTransitionType.none) {
        sceneWidget = _TransitionWrapper(
          transition: transitionIn,
          isEntry: true,
          sceneStartFrame: startFrame,
          child: sceneWidget,
        );
      }

      // Apply exit animation if transition specified
      if (transitionOut != null &&
          transitionOut.type != SceneTransitionType.none) {
        sceneWidget = _TransitionWrapper(
          transition: transitionOut,
          isEntry: false,
          sceneEndFrame: endFrame,
          child: sceneWidget,
        );
      }

      // Wrap with Layer for timing, and Positioned.fill so scene fills the video
      // Also wrap with SceneContext so descendants can access the scene's global timing
      sceneLayers.add(
        Positioned.fill(
          child: Layer(
            startFrame: startFrame,
            endFrame: endFrame,
            fadeInFrames: fadeIn,
            fadeOutFrames: fadeOut,
            fadeInCurve: transitionIn?.curve ?? scene.fadeInCurve,
            fadeOutCurve: transitionOut?.curve ?? scene.fadeOutCurve,
            child: SceneContext(
              sceneStartFrame: startFrame,
              sceneDurationInFrames: scene.durationInFrames,
              child: sceneWidget,
            ),
          ),
        ),
      );
    }

    // Build the scene stack
    Widget content = LayerStack(fit: StackFit.expand, children: sceneLayers);

    // Wrap with background audio if specified
    if (backgroundMusicAsset != null) {
      content = BackgroundAudio(
        source: AudioSource.asset(backgroundMusicAsset!),
        volume: musicVolume,
        fadeInFrames: musicFadeInFrames,
        fadeOutFrames: musicFadeOutFrames,
        loop: true,
        child: content,
      );
    }

    // Create the video composition
    return VideoComposition(
      fps: fps,
      durationInFrames: totalDuration,
      width: width,
      height: height,
      encoding: encoding,
      child: content,
    );
  }
}

/// Internal widget that applies scene transitions.
class _TransitionWrapper extends StatelessWidget {
  final SceneTransition transition;
  final bool isEntry;
  final int? sceneStartFrame;
  final int? sceneEndFrame;
  final Widget child;

  const _TransitionWrapper({
    required this.transition,
    required this.isEntry,
    this.sceneStartFrame,
    this.sceneEndFrame,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Use TimeConsumer to get frame-based animation
    return _TransitionAnimator(
      transition: transition,
      isEntry: isEntry,
      sceneStartFrame: sceneStartFrame,
      sceneEndFrame: sceneEndFrame,
      child: child,
    );
  }
}

/// Animator widget that applies transition effects based on current frame.
class _TransitionAnimator extends StatelessWidget {
  final SceneTransition transition;
  final bool isEntry;
  final int? sceneStartFrame;
  final int? sceneEndFrame;
  final Widget child;

  const _TransitionAnimator({
    required this.transition,
    required this.isEntry,
    this.sceneStartFrame,
    this.sceneEndFrame,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final currentFrame = FrameProvider.of(context) ?? 0;
    final duration = transition.durationInFrames;

    // Calculate progress based on entry/exit
    double progress;
    if (isEntry) {
      // Entry: animate from 0 to 1 during first `duration` frames of scene
      final start = sceneStartFrame ?? 0;
      final elapsed = currentFrame - start;
      progress = duration > 0 ? (elapsed / duration).clamp(0.0, 1.0) : 1.0;
    } else {
      // Exit: animate from 0 to 1 during last `duration` frames before scene end
      final end = sceneEndFrame ?? 0;
      final exitStart = end - duration;
      final elapsed = currentFrame - exitStart;
      progress = duration > 0 ? (elapsed / duration).clamp(0.0, 1.0) : 0.0;
    }

    // Apply curve
    final curvedProgress = transition.curve.transform(progress);

    // Apply transition based on type
    return _applyTransition(curvedProgress);
  }

  Widget _applyTransition(double progress) {
    // For entry: progress goes 0->1, we want to animate IN
    // For exit: progress goes 0->1, we want to animate OUT

    switch (transition.type) {
      case SceneTransitionType.none:
        return child;

      case SceneTransitionType.crossFade:
        // Crossfade is handled by Layer's fade, just return child
        return child;

      case SceneTransitionType.slideLeft:
        final offset = isEntry
            ? Offset(1.0 - progress, 0) // Slide in from right
            : Offset(-progress, 0); // Slide out to left
        return FractionalTranslation(translation: offset, child: child);

      case SceneTransitionType.slideRight:
        final offset = isEntry
            ? Offset(progress - 1.0, 0) // Slide in from left
            : Offset(progress, 0); // Slide out to right
        return FractionalTranslation(translation: offset, child: child);

      case SceneTransitionType.slideUp:
        final offset = isEntry
            ? Offset(0, 1.0 - progress) // Slide in from bottom
            : Offset(0, -progress); // Slide out to top
        return FractionalTranslation(translation: offset, child: child);

      case SceneTransitionType.slideDown:
        final offset = isEntry
            ? Offset(0, progress - 1.0) // Slide in from top
            : Offset(0, progress); // Slide out to bottom
        return FractionalTranslation(translation: offset, child: child);

      case SceneTransitionType.scale:
        final scale = isEntry
            ? progress // Scale up from 0 to 1
            : 1.0 - progress; // Scale down from 1 to 0
        return Transform.scale(scale: scale.clamp(0.001, 1.0), child: child);

      case SceneTransitionType.wipe:
        return ClipRect(
          clipper: _WipeClipper(
            progress: isEntry ? progress : 1.0 - progress,
            direction: transition.wipeDirection ?? WipeDirection.leftToRight,
          ),
          child: child,
        );

      case SceneTransitionType.zoomWarp:
        final maxZoom = transition.maxZoom;
        final scale = isEntry
            ? 1.0 +
                  (maxZoom - 1.0) *
                      (1.0 - progress) // Zoom out from maxZoom to 1
            : 1.0 + (maxZoom - 1.0) * progress; // Zoom in from 1 to maxZoom
        final opacity = isEntry ? progress : 1.0 - progress;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            alignment: transition.zoomTarget ?? Alignment.center,
            child: child,
          ),
        );

      case SceneTransitionType.colorBleed:
        // Color bleed: overlay a color that fades in/out
        final bleedOpacity = isEntry ? 1.0 - progress : progress;
        final color = transition.bleedColor ?? const Color(0xFF000000);
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (bleedOpacity > 0.001)
              IgnorePointer(
                child: ColoredBox(
                  color: color.withValues(alpha: bleedOpacity * 0.8),
                ),
              ),
          ],
        );
    }
  }
}

/// Custom clipper for wipe transitions.
class _WipeClipper extends CustomClipper<Rect> {
  final double progress;
  final WipeDirection direction;

  _WipeClipper({required this.progress, required this.direction});

  @override
  Rect getClip(Size size) {
    switch (direction) {
      case WipeDirection.leftToRight:
        return Rect.fromLTWH(0, 0, size.width * progress, size.height);
      case WipeDirection.rightToLeft:
        final left = size.width * (1.0 - progress);
        return Rect.fromLTWH(left, 0, size.width * progress, size.height);
      case WipeDirection.topToBottom:
        return Rect.fromLTWH(0, 0, size.width, size.height * progress);
      case WipeDirection.bottomToTop:
        final top = size.height * (1.0 - progress);
        return Rect.fromLTWH(0, top, size.width, size.height * progress);
    }
  }

  @override
  bool shouldReclip(covariant _WipeClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.direction != direction;
  }
}
