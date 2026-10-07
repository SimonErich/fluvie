import 'package:meta/meta.dart';

/// The build-step layout of one slide, computed the way the presenter's
/// `compileSlidePlans` computes it: step membership from the scene's `steps`
/// list (unlisted children are the base step) and one marker per listed
/// step, sitting where the previous step's entrances settle — the frame the
/// next click would land on.
///
/// Everything here is scene-relative and pure; the model builder feeds it
/// introspected enter spans and the panel feeds marker gestures back through
/// [stepsAfterMarkerInsert], [stepsAfterMarkerMove], and
/// [stepsAfterMarkerRemove].
@immutable
final class SlideStepLayout {
  /// Creates the layout; use [computeStepLayout].
  const SlideStepLayout({
    required this.memberIds,
    required this.markerFrames,
    required this.revealEnds,
  });

  /// The top-level member ids of each step in scene child order; index 0 is
  /// the base step (children no step lists).
  final List<List<String>> memberIds;

  /// One frame per listed step: where step `k` settles — the boundary
  /// between step `k` and step `k + 1`, mirroring the compiler's settle rule
  /// (max enter end over the step's elements, group children included, 0
  /// when none animates in).
  final List<int> markerFrames;

  /// The reveal end per top-level id: the latest enter end of the element
  /// and its group children, or 0 when nothing animates in — the partition
  /// key marker gestures split membership by.
  final Map<String, int> revealEnds;
}

/// The scene's authored `steps` element lists, shape-tolerant (a malformed
/// list reads as empty — validation reports it, the timeline stays up).
List<List<String>> sceneStepElementIds(Map<String, Object?> sceneJson) {
  final steps = sceneJson['steps'];
  if (steps is! List) return const [];
  return [
    for (final step in steps.whereType<Map<String, Object?>>())
      [...(step['elements'] as List? ?? const []).whereType<String>()],
  ];
}

/// Computes the [SlideStepLayout] of one slide from its child order
/// ([topLevelIds]), its authored `steps` element lists ([stepIds]), the
/// group children of each top-level id, and each element's scene-relative
/// enter end (null for no entrance).
SlideStepLayout computeStepLayout({
  required List<String> topLevelIds,
  required List<List<String>> stepIds,
  required List<String> Function(String id) childIdsOf,
  required int? Function(String id) enterEndOf,
}) {
  final revealEnds = <String, int>{};
  int reveal(String id) {
    var latest = enterEndOf(id) ?? 0;
    for (final child in childIdsOf(id)) {
      final end = enterEndOf(child);
      if (end != null && end > latest) latest = end;
    }
    return latest;
  }

  final stepOf = <String, int>{
    for (var s = 0; s < stepIds.length; s++)
      for (final id in stepIds[s]) id: s + 1,
  };
  final members = List.generate(stepIds.length + 1, (_) => <String>[]);
  for (final id in topLevelIds) {
    revealEnds[id] = reveal(id);
    members[stepOf[id] ?? 0].add(id);
  }
  for (final id in stepOf.keys) {
    revealEnds.putIfAbsent(id, () => reveal(id));
  }
  int settle(List<String> ids) {
    var latest = 0;
    for (final id in ids) {
      final end = revealEnds[id]!;
      if (end > latest) latest = end;
    }
    return latest;
  }

  return SlideStepLayout(
    memberIds: List.unmodifiable([for (final ids in members) List<String>.unmodifiable(ids)]),
    markerFrames: List.unmodifiable([
      for (var s = 0; s < stepIds.length; s++) settle(members[s]),
    ]),
    revealEnds: Map.unmodifiable(revealEnds),
  );
}

/// The scene's `steps` list after inserting a marker at [frame]: the step
/// whose region holds the frame splits by reveal end (at or before the
/// marker stays, later moves into a new following step). Splitting the base
/// step creates the first listed entry; a marker that separates nothing
/// returns null (refused). Notes stay with the earlier part.
List<Object?>? stepsAfterMarkerInsert({
  required List<Object?> stepsJson,
  required SlideStepLayout layout,
  required int frame,
}) {
  var region = layout.markerFrames.length;
  for (var k = 0; k < layout.markerFrames.length; k++) {
    if (frame < layout.markerFrames[k]) {
      region = k;
      break;
    }
  }
  final split = _partition(layout.memberIds[region], layout.revealEnds, frame);
  if (split.earlier.isEmpty || split.later.isEmpty) return null;
  final next = [for (final step in stepsJson) _copyStep(step)];
  if (region == 0) {
    next.insert(0, {'elements': split.later});
  } else {
    final original = next[region - 1];
    next[region - 1] = {...original, 'elements': split.earlier};
    next.insert(region, {'elements': split.later});
  }
  return next;
}

/// The scene's `steps` list after dragging marker [boundary] to [frame]:
/// the two adjacent steps re-partition by reveal end. Emptying a listed
/// step returns null (refused); the base step may empty.
List<Object?>? stepsAfterMarkerMove({
  required List<Object?> stepsJson,
  required SlideStepLayout layout,
  required int boundary,
  required int frame,
}) {
  final order = {for (var i = 0; i < layout.memberIds.length; i++) ...layout.memberIds[i]}.toList();
  final union = [...layout.memberIds[boundary], ...layout.memberIds[boundary + 1]]
    ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
  final split = _partition(union, layout.revealEnds, frame);
  if (split.later.isEmpty) return null;
  if (boundary > 0 && split.earlier.isEmpty) return null;
  final next = [for (final step in stepsJson) _copyStep(step)];
  if (boundary > 0) {
    final earlier = next[boundary - 1];
    next[boundary - 1] = {...earlier, 'elements': split.earlier};
  }
  final later = next[boundary];
  next[boundary] = {...later, 'elements': split.later};
  return next;
}

/// The scene's `steps` list after removing marker [boundary]: the step
/// after it merges into the step before it. Boundary 0 folds the first
/// listed step back into the base (its notes go with it); later boundaries
/// concatenate elements, the earlier step's notes winning and a note-less
/// earlier step adopting the later's.
List<Object?> stepsAfterMarkerRemove({required List<Object?> stepsJson, required int boundary}) {
  final next = [for (final step in stepsJson) _copyStep(step)];
  if (boundary == 0) {
    next.removeAt(0);
    return next;
  }
  final earlier = next[boundary - 1];
  final later = next[boundary];
  next[boundary - 1] = {
    ...earlier,
    'elements': [...earlier['elements']! as List, ...later['elements']! as List],
    if (earlier['notes'] == null && later['notes'] != null) 'notes': later['notes'],
  };
  next.removeAt(boundary);
  return next;
}

({List<String> earlier, List<String> later}) _partition(
  List<String> ids,
  Map<String, int> revealEnds,
  int frame,
) => (
  earlier: [
    for (final id in ids)
      if (revealEnds[id]! <= frame) id,
  ],
  later: [
    for (final id in ids)
      if (revealEnds[id]! > frame) id,
  ],
);

Map<String, Object?> _copyStep(Object? step) => {...step! as Map<String, Object?>};
