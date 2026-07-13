import 'package:meta/meta.dart';

/// One place in a presentation: which slide, and which build step within it.
///
/// Positions order flat — every step of slide 0, then every step of slide 1 —
/// which is exactly the order `next` and `back` traverse.
@immutable
final class PresentationPosition implements Comparable<PresentationPosition> {
  /// Creates the position at [slide], [step].
  const PresentationPosition(this.slide, this.step);

  /// The slide index (one scene = one slide).
  final int slide;

  /// The build step within the slide; 0 is the slide's own content.
  final int step;

  @override
  int compareTo(PresentationPosition other) =>
      slide != other.slide ? slide.compareTo(other.slide) : step.compareTo(other.step);

  @override
  bool operator ==(Object other) =>
      other is PresentationPosition && other.slide == slide && other.step == step;

  @override
  int get hashCode => Object.hash(PresentationPosition, slide, step);

  @override
  String toString() => 'PresentationPosition($slide.$step)';
}
