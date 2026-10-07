import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable, listEquals;

// obers_ui upstream candidate: the gradient editor's value model — plain
// stops, kind, and angle, free of any document vocabulary.

/// How a [GradientEditorValue] paints: along an angle, or out from the
/// center.
enum GradientEditorKind {
  /// A straight ramp along [GradientEditorValue.angle].
  linear,

  /// A circular ramp from the center outward; the angle does not apply.
  radial,
}

/// One color stop of a [GradientEditorValue].
@immutable
final class GradientEditorStop {
  /// A stop of [color] at [offset] (0..1 along the ramp).
  const GradientEditorStop({required this.offset, required this.color});

  /// Where along the ramp this stop sits, 0..1.
  final double offset;

  /// The stop's color.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is GradientEditorStop && other.offset == offset && other.color == color;

  @override
  int get hashCode => Object.hash(offset, color);
}

/// What the gradient editor edits: ordered color [stops], the paint [kind],
/// and the linear [angle] in degrees (0 points left to right, 90 top to
/// bottom).
@immutable
final class GradientEditorValue {
  /// A gradient of [stops] (sorted by offset), painted as [kind] at
  /// [angle].
  const GradientEditorValue({
    required this.stops,
    this.kind = GradientEditorKind.linear,
    this.angle = 45,
  });

  /// The color stops, ascending by [GradientEditorStop.offset].
  final List<GradientEditorStop> stops;

  /// Linear or radial.
  final GradientEditorKind kind;

  /// The linear ramp's direction in degrees, normalized 0..360.
  final double angle;

  /// This value with the given fields replaced.
  GradientEditorValue copyWith({
    List<GradientEditorStop>? stops,
    GradientEditorKind? kind,
    double? angle,
  }) => GradientEditorValue(
    stops: stops ?? this.stops,
    kind: kind ?? this.kind,
    angle: angle ?? this.angle,
  );

  @override
  bool operator ==(Object other) =>
      other is GradientEditorValue &&
      listEquals(other.stops, stops) &&
      other.kind == kind &&
      other.angle == angle;

  @override
  int get hashCode => Object.hash(Object.hashAll(stops), kind, angle);
}
