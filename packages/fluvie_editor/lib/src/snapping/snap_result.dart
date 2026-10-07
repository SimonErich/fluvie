import 'dart:ui' show Rect;

import 'package:fluvie_editor/src/snapping/snap_line.dart';

/// What one snap query produced: the (possibly adjusted) rect and the lines
/// the overlay should draw, at most one per axis, vertical first.
final class SnapResult {
  /// The result of a snap query.
  const SnapResult(this.rect, this.lines);

  /// The adjusted rect (the input rect when nothing snapped).
  final Rect rect;

  /// The active snap lines, vertical before horizontal. Empty when nothing
  /// snapped.
  final List<SnapLine> lines;
}
