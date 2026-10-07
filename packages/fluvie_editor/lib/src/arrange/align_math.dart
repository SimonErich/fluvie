import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/painting.dart' show Axis;

/// The six alignment edges of the arrange menu.
enum AlignEdge {
  /// Left edges meet.
  left,

  /// Horizontal centers meet.
  centerX,

  /// Right edges meet.
  right,

  /// Top edges meet.
  top,

  /// Vertical centers meet.
  centerY,

  /// Bottom edges meet.
  bottom,
}

/// The per-element translation aligning [rects] on [edge].
///
/// Two or more rects align against the selection's own bounding box; a
/// single rect aligns against the [frame] (the slide, or an entered group's
/// box). Deltas are in the same pixel space as the rects.
Map<String, Offset> alignDeltas(Map<String, Rect> rects, AlignEdge edge, Size frame) {
  if (rects.isEmpty) return const {};
  final reference = rects.length == 1
      ? Offset.zero & frame
      : rects.values.reduce((a, b) => a.expandToInclude(b));
  return {
    for (final entry in rects.entries) entry.key: _alignDelta(entry.value, reference, edge),
  };
}

Offset _alignDelta(Rect rect, Rect reference, AlignEdge edge) => switch (edge) {
  AlignEdge.left => Offset(reference.left - rect.left, 0),
  AlignEdge.centerX => Offset(reference.center.dx - rect.center.dx, 0),
  AlignEdge.right => Offset(reference.right - rect.right, 0),
  AlignEdge.top => Offset(0, reference.top - rect.top),
  AlignEdge.centerY => Offset(0, reference.center.dy - rect.center.dy),
  AlignEdge.bottom => Offset(0, reference.bottom - rect.bottom),
};

/// The per-element translation spacing [rects] equally along [axis].
///
/// The outermost rects (by center) pin the span; the ones between get equal
/// gaps. Throws an [ArgumentError] for fewer than three rects — there is
/// nothing to distribute.
Map<String, Offset> distributeDeltas(Map<String, Rect> rects, Axis axis) {
  if (rects.length < 3) {
    throw ArgumentError.value(rects, 'rects', 'Distributing needs three or more elements');
  }
  double along(Rect rect) => axis == Axis.horizontal ? rect.center.dx : rect.center.dy;
  double start(Rect rect) => axis == Axis.horizontal ? rect.left : rect.top;
  double extent(Rect rect) => axis == Axis.horizontal ? rect.width : rect.height;
  final ids = rects.keys.toList()..sort((a, b) => along(rects[a]!).compareTo(along(rects[b]!)));
  final first = rects[ids.first]!;
  final last = rects[ids.last]!;
  final span = (start(last) + extent(last)) - start(first);
  final occupied = ids.fold<double>(0, (sum, id) => sum + extent(rects[id]!));
  final gap = (span - occupied) / (ids.length - 1);
  final deltas = <String, Offset>{ids.first: Offset.zero, ids.last: Offset.zero};
  var cursor = start(first) + extent(first) + gap;
  for (final id in ids.sublist(1, ids.length - 1)) {
    final shift = cursor - start(rects[id]!);
    deltas[id] = axis == Axis.horizontal ? Offset(shift, 0) : Offset(0, shift);
    cursor += extent(rects[id]!) + gap;
  }
  return deltas;
}
