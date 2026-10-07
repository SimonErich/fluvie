part of 'transition.dart';

/// Which scene-to-scene blend a [Transition] performs.
enum TransitionKind {
  /// A hard cut: no blend window, the next scene simply starts.
  cut,

  /// A dissolve: the incoming scene fades in over the outgoing one.
  crossFade,

  /// A travelling reveal: the incoming scene is uncovered along an [Edge].
  wipe,

  /// The outgoing scene scales up and fades out, pushing *into* the cut.
  zoom,

  /// A push: the incoming scene slides in while the outgoing slides away.
  slide,

  /// An out-of-tree strategy registered under [Transition.customKind].
  custom,
}
