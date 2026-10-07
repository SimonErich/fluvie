import 'dart:ui' show Color;

import 'package:fluvie_editor/src/widgets/gradient_editor/gradient_editor_value.dart';

// obers_ui upstream candidate: the pure stop operations behind the gradient
// editor, unit-testable without a widget tree.

/// The gradient's color at [fraction]: the neighboring stops lerped, the
/// edge color beyond the first or last stop.
Color gradientColorAt(GradientEditorValue value, double fraction) {
  final stops = value.stops;
  if (fraction <= stops.first.offset) return stops.first.color;
  if (fraction >= stops.last.offset) return stops.last.color;
  for (var i = 0; i < stops.length - 1; i++) {
    final left = stops[i];
    final right = stops[i + 1];
    if (fraction > right.offset) continue;
    final span = right.offset - left.offset;
    final t = span == 0 ? 1.0 : (fraction - left.offset) / span;
    return Color.lerp(left.color, right.color, t)!;
  }
  // coverage:ignore-line unreachable the loop always returns once fraction is inside the span
  return stops.last.color;
}

/// [value] with a stop added at [fraction], colored by sampling the
/// gradient there — a new stop never changes the visible ramp. Returns the
/// new value and the added stop's index.
({GradientEditorValue value, int index}) gradientStopAdded(
  GradientEditorValue value,
  double fraction,
) {
  final offset = fraction.clamp(0.0, 1.0);
  final added = GradientEditorStop(offset: offset, color: gradientColorAt(value, offset));
  final index = value.stops.indexWhere((stop) => stop.offset > offset);
  final at = index < 0 ? value.stops.length : index;
  final stops = [...value.stops]..insert(at, added);
  return (value: value.copyWith(stops: stops), index: at);
}

/// [value] with stop [index] moved to [fraction], clamped to 0..1 and to
/// its neighbors' offsets — a stop never crosses another.
GradientEditorValue gradientStopMoved(GradientEditorValue value, int index, double fraction) {
  final stops = value.stops;
  final lower = index == 0 ? 0.0 : stops[index - 1].offset;
  final upper = index == stops.length - 1 ? 1.0 : stops[index + 1].offset;
  final moved = GradientEditorStop(
    offset: fraction.clamp(lower, upper),
    color: stops[index].color,
  );
  return value.copyWith(stops: [...stops]..[index] = moved);
}

/// [value] without stop [index], or null when only two stops remain — a
/// gradient keeps at least two.
GradientEditorValue? gradientStopRemoved(GradientEditorValue value, int index) {
  if (value.stops.length <= 2) return null;
  return value.copyWith(stops: [...value.stops]..removeAt(index));
}
