part of 'editor_command.dart';

/// Aligns a selection on one edge: two or more elements against the
/// selection's own bounds, a single element against the slide.
final class AlignElementsCommand extends EditorCommand {
  /// Aligns the elements of [rects] (their resolved layout rects, in
  /// [frame] pixels) on [edge].
  const AlignElementsCommand({required this.rects, required this.edge, required this.frame});

  /// The resolved layout rect per element id — captured at dispatch so redo
  /// stays deterministic (intrinsic sizes included).
  final Map<String, Rect> rects;

  /// The edge the selection aligns on.
  final AlignEdge edge;

  /// The pixel space the rects live in (the slide size, or an entered
  /// group's box).
  final Size frame;

  @override
  EditorDocument apply(EditorDocument document) =>
      _movedByDeltas(document, rects, alignDeltas(rects, edge, frame), frame);

  @override
  String get label => switch (edge) {
    AlignEdge.left => 'Align left',
    AlignEdge.centerX => 'Align center',
    AlignEdge.right => 'Align right',
    AlignEdge.top => 'Align top',
    AlignEdge.centerY => 'Align middle',
    AlignEdge.bottom => 'Align bottom',
  };

  @override
  Set<String> get affectedIds => rects.keys.toSet();
}

/// Spaces three or more elements equally along one axis, the outermost two
/// pinned.
final class DistributeElementsCommand extends EditorCommand {
  /// Distributes the elements of [rects] (their resolved layout rects, in
  /// [frame] pixels) along [axis].
  const DistributeElementsCommand({required this.rects, required this.axis, required this.frame});

  /// The resolved layout rect per element id — captured at dispatch so redo
  /// stays deterministic (intrinsic sizes included).
  final Map<String, Rect> rects;

  /// The distribution axis.
  final Axis axis;

  /// The pixel space the rects live in (the slide size, or an entered
  /// group's box).
  final Size frame;

  @override
  EditorDocument apply(EditorDocument document) =>
      _movedByDeltas(document, rects, distributeDeltas(rects, axis), frame);

  @override
  String get label => axis == Axis.horizontal ? 'Distribute horizontally' : 'Distribute vertically';

  @override
  Set<String> get affectedIds => rects.keys.toSet();
}

/// Writes each element's placement shifted by its delta — through the same
/// anchor-preserving move math the gizmo uses, so intrinsic elements stay
/// intrinsic. Zero deltas leave the element JSON untouched.
EditorDocument _movedByDeltas(
  EditorDocument document,
  Map<String, Rect> rects,
  Map<String, Offset> deltas,
  Size frame,
) {
  var current = document;
  for (final entry in deltas.entries) {
    if (entry.value == Offset.zero) continue;
    final transform = document.elementJson(entry.key)?['transform'];
    final placement = transform == null
        ? const Placement(x: 0.5, y: 0.5)
        : decodePlacement(transform);
    final moved = TransformDrag.movedBy(
      {entry.key: (rect: rects[entry.key]!, placement: placement)},
      entry.value,
      frame,
    );
    current = current.setTransform(entry.key, encodePlacement(moved[entry.key]!));
  }
  return current;
}
