import 'package:flutter/widgets.dart';
import '../../presentation/layer.dart';
import '../../presentation/layer_stack.dart';
import '../background/background.dart';
import 'scene_transition.dart';

/// Provides context information about the current scene to descendants.
///
/// Use [SceneContext.of] to access the scene's global start frame, which
/// allows child widgets like [EmbeddedVideo] to correctly calculate their
/// position in the overall composition timeline.
class SceneContext extends InheritedWidget {
  /// The global frame where this scene starts in the composition.
  final int sceneStartFrame;

  /// The duration of this scene in frames.
  final int sceneDurationInFrames;

  const SceneContext({
    super.key,
    required this.sceneStartFrame,
    required this.sceneDurationInFrames,
    required super.child,
  });

  /// Gets the scene context from the widget tree.
  ///
  /// Returns null if no [SceneContext] ancestor exists.
  static SceneContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SceneContext>();
  }

  @override
  bool updateShouldNotify(SceneContext oldWidget) {
    return sceneStartFrame != oldWidget.sceneStartFrame ||
        sceneDurationInFrames != oldWidget.sceneDurationInFrames;
  }
}

/// A scene in a video composition.
///
/// [Scene] represents a time-bounded section of a video with its own
/// background, content, and transitions. Scenes are stacked in a [Video]
/// widget and play sequentially.
///
/// Example:
/// ```dart
/// Scene(
///   durationInFrames: 120,
///   background: Background.gradient(
///     colors: {0: Colors.red, 60: Colors.blue},
///   ),
///   transitionIn: SceneTransition.crossFade(durationInFrames: 15),
///   children: [
///     VCenter(
///       child: AnimatedText('Hello World'),
///     ),
///   ],
/// )
/// ```
class Scene extends StatelessWidget {
  /// Duration of this scene in frames.
  final int durationInFrames;

  /// The background for this scene.
  final Background? background;

  /// The content widgets for this scene.
  ///
  /// These are stacked on top of the background.
  final List<Widget> children;

  /// Transition applied when entering this scene.
  final SceneTransition? transitionIn;

  /// Transition applied when exiting this scene.
  final SceneTransition? transitionOut;

  /// Fade-in duration in frames (applied after transitionIn).
  final int fadeInFrames;

  /// Fade-out duration in frames (applied before transitionOut).
  final int fadeOutFrames;

  /// Easing curve for fade-in.
  final Curve fadeInCurve;

  /// Easing curve for fade-out.
  final Curve fadeOutCurve;

  /// Creates a scene.
  const Scene({
    super.key,
    required this.durationInFrames,
    this.background,
    this.children = const [],
    this.transitionIn,
    this.transitionOut,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.fadeInCurve = Curves.easeOut,
    this.fadeOutCurve = Curves.easeIn,
  });

  /// Creates a scene with a solid color background.
  ///
  /// Example:
  /// ```dart
  /// Scene.solid(
  ///   durationInFrames: 120,
  ///   color: Colors.black,
  ///   children: [VCenter(child: Text('Hello'))],
  /// )
  /// ```
  Scene.solid({
    Key? key,
    required int durationInFrames,
    required Color color,
    List<Widget> children = const [],
    SceneTransition? transitionIn,
    SceneTransition? transitionOut,
    int fadeInFrames = 0,
    int fadeOutFrames = 0,
    Curve fadeInCurve = Curves.easeOut,
    Curve fadeOutCurve = Curves.easeIn,
  }) : this(
         key: key,
         durationInFrames: durationInFrames,
         background: Background.solid(color),
         children: children,
         transitionIn: transitionIn,
         transitionOut: transitionOut,
         fadeInFrames: fadeInFrames,
         fadeOutFrames: fadeOutFrames,
         fadeInCurve: fadeInCurve,
         fadeOutCurve: fadeOutCurve,
       );

  /// Creates a scene with a gradient background.
  ///
  /// Example:
  /// ```dart
  /// Scene.gradient(
  ///   durationInFrames: 120,
  ///   colors: {0: Colors.blue, 120: Colors.purple},
  ///   children: [VCenter(child: Text('Hello'))],
  /// )
  /// ```
  Scene.gradient({
    Key? key,
    required int durationInFrames,
    required Map<int, Color> colors,
    List<Widget> children = const [],
    GradientType type = GradientType.linear,
    AlignmentGeometry begin = Alignment.topCenter,
    AlignmentGeometry end = Alignment.bottomCenter,
    SceneTransition? transitionIn,
    SceneTransition? transitionOut,
    int fadeInFrames = 0,
    int fadeOutFrames = 0,
  }) : this(
         key: key,
         durationInFrames: durationInFrames,
         background: Background.gradient(
           colors: colors,
           type: type,
           begin: begin,
           end: end,
         ),
         children: children,
         transitionIn: transitionIn,
         transitionOut: transitionOut,
         fadeInFrames: fadeInFrames,
         fadeOutFrames: fadeOutFrames,
       );

  /// Creates a scene with crossfade transitions preset.
  ///
  /// Example:
  /// ```dart
  /// Scene.crossFade(
  ///   durationInFrames: 120,
  ///   transitionFrames: 15,
  ///   background: Background.solid(Colors.black),
  ///   children: [VCenter(child: Text('Hello'))],
  /// )
  /// ```
  const Scene.crossFade({
    super.key,
    required this.durationInFrames,
    this.background,
    this.children = const [],
    int transitionFrames = 15,
    this.fadeInCurve = Curves.easeOut,
    this.fadeOutCurve = Curves.easeIn,
  }) : transitionIn = const SceneTransition.crossFade(durationInFrames: 15),
       transitionOut = const SceneTransition.crossFade(durationInFrames: 15),
       fadeInFrames = transitionFrames,
       fadeOutFrames = transitionFrames;

  /// Creates an empty scene (useful for spacing or transition-only scenes).
  ///
  /// Example:
  /// ```dart
  /// Scene.empty(durationInFrames: 30)
  /// ```
  const Scene.empty({
    super.key,
    required this.durationInFrames,
    this.transitionIn,
    this.transitionOut,
  }) : background = null,
       children = const [],
       fadeInFrames = 0,
       fadeOutFrames = 0,
       fadeInCurve = Curves.easeOut,
       fadeOutCurve = Curves.easeIn;

  @override
  Widget build(BuildContext context) {
    // Build the scene content
    final List<Widget> layers = [];

    // Add background if specified
    if (background != null) {
      layers.add(
        Positioned.fill(child: background!.build(context, durationInFrames)),
      );
    }

    // Add children
    layers.addAll(children);

    // Create the scene stack
    Widget sceneContent = LayerStack(children: layers);

    // Note: Transitions are handled by the parent Video widget
    // which has knowledge of adjacent scenes.
    return sceneContent;
  }

  /// Builds this scene with timing information.
  ///
  /// Used internally by [Video] to place scenes at the correct time.
  Widget buildWithTiming(int startFrame) {
    return Layer(
      startFrame: startFrame,
      endFrame: startFrame + durationInFrames,
      fadeInFrames: fadeInFrames,
      fadeOutFrames: fadeOutFrames,
      fadeInCurve: fadeInCurve,
      fadeOutCurve: fadeOutCurve,
      child: this,
    );
  }
}
