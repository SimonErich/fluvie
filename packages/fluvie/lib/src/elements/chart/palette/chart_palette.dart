/// @docImport 'package:fluvie/src/theme/fluvie_tokens.dart';
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/painting.dart' show Color;
import 'package:meta/meta.dart' show immutable;

/// An ordered list of series colors a chart cycles through.
///
/// A palette assigns one color per series / segment by index via [colorAt],
/// which wraps modularly so a chart with more segments than palette slots keeps
/// assigning colors rather than running out. It is part of [FluvieTokens] and a
/// per-series `color:` overrides the slot the palette would pick.
///
/// It holds only [Color]s and is value-equal by its color list (deep
/// equality), so identical palettes produce identical chart geometry — the
/// frame-caching contract.
///
/// ```dart
/// const ChartPalette([Color(0xFF6C5CE7), Color(0xFF00B894)])
/// ```
@immutable
final class ChartPalette {
  /// Creates a palette over the ordered [colors], which must not be empty.
  const ChartPalette(this.colors);

  /// The ordered series colors; slot order is assignment order.
  final List<Color> colors;

  /// The color for series / segment [index], wrapping modularly past the last
  /// slot (`colorAt(colors.length)` is the first color again).
  ///
  /// An empty palette is rejected here rather than crashing with an integer
  /// division by zero: the const constructor cannot assert a list's length in
  /// this SDK, so the guard lives at the one place that divides by it.
  Color colorAt(int index) {
    assert(colors.isNotEmpty, 'ChartPalette needs at least one color');
    return colors[index % colors.length];
  }

  @override
  bool operator ==(Object other) => other is ChartPalette && listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hash(ChartPalette, Object.hashAll(colors));

  @override
  String toString() => 'ChartPalette(${colors.length} colors)';
}
