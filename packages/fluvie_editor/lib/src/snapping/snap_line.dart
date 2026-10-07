import 'package:meta/meta.dart' show immutable;

// obers_ui upstream candidate: the typed snap-line vocabulary any snapping
// canvas shares (kinds, orientation, and the line value itself).

/// What produced a snap line.
enum SnapKind {
  /// Another element's (or the slide's) edge.
  edge,

  /// Another element's (or the slide's) center.
  center,

  /// An equal-spacing hint between or beyond aligned elements.
  spacing,

  /// A manual guide dragged from a ruler.
  guide,

  /// A grid line.
  grid,
}

/// Which way a snap line runs.
enum SnapOrientation {
  /// A vertical line: it pins an x position.
  vertical,

  /// A horizontal line: it pins a y position.
  horizontal,
}

/// One active snap line: what kind it is, which way it runs, and where it
/// sits in canvas pixels. The overlay draws these; the engine emits at most
/// one per axis per update.
@immutable
final class SnapLine {
  /// A [kind] line running [orientation] at [position] canvas pixels.
  const SnapLine({required this.kind, required this.orientation, required this.position});

  /// What produced the line.
  final SnapKind kind;

  /// Which way the line runs.
  final SnapOrientation orientation;

  /// The line's canvas-pixel position along the axis it pins.
  final double position;

  @override
  bool operator ==(Object other) =>
      other is SnapLine &&
      other.kind == kind &&
      other.orientation == orientation &&
      other.position == position;

  @override
  int get hashCode => Object.hash(kind, orientation, position);

  @override
  String toString() => 'SnapLine(${kind.name}, ${orientation.name}, $position)';
}
