import 'package:flutter/rendering.dart' show Offset, Rect;

/// The swatch rects for a [count]-entry legend laid out left to right.
///
/// The first swatch sits at [origin] and each is a [swatch]-px square; the next
/// swatch advances by [step] pixels on the x axis. The layout is pure geometry
/// so it is unit-tested without a canvas, and an empty legend yields no rects.
List<Rect> legendLayout({
  required int count,
  required Offset origin,
  required double swatch,
  required double step,
}) => [
  for (var i = 0; i < count; i++) Rect.fromLTWH(origin.dx + step * i, origin.dy, swatch, swatch),
];
