part of 'element_transition_spec.dart';

/// Resolves transitions whose clips are direct children of this holding list.
/// Rejects unknown clips, wrong lanes, gaps, branching chains and blends that
/// cannot fit; the scene offset resolver enforces the same head+tail rule.
ElementTransitionLayout resolveElementTransitionLayout({
  required List<ElementSpec> children,
  required List<ElementTransitionSpec> transitions,
  required int fps,
  required int durationFrames,
  List<String> path = const [],
}) => resolveClipTransitionLayout(
  children: [
    for (final child in children)
      ClipTransitionElement(
        id: child.id,
        isClip: child.type == 'Clip',
        lane: child.lane,
        window: child.window,
        shared: child.shared != null,
      ),
  ],
  transitions: transitions,
  fps: fps,
  durationFrames: durationFrames,
  path: path,
);

/// The same window planner for native widgets and serialized documents.
ElementTransitionLayout resolveClipTransitionLayout({
  required List<ClipTransitionElement> children,
  required List<ElementTransitionSpec> transitions,
  required int fps,
  required int durationFrames,
  List<String> path = const [],
}) {
  final byId = {
    for (final child in children)
      if (child.id != null) child.id!: child,
  };
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: durationFrames);
  final authored = {
    for (final child in children)
      if (child.id != null) child.id!: resolveElementWindow(child.window, scope),
  };
  final outgoing = <String, ElementTransitionSpec>{};
  final incoming = <String, ElementTransitionSpec>{};
  for (var i = 0; i < transitions.length; i++) {
    final edge = transitions[i];
    final a = byId[edge.outgoing];
    final b = byId[edge.incoming];
    final location = [...path, 'transitions', '$i'];
    if (a == null || b == null) {
      throw FluvieSpecError(
        'Both transition ids must exist in the same scene or group',
        path: location,
      );
    }
    if (!a.isClip || !b.isClip) {
      throw FluvieSpecError('Clip transitions pair two Clip elements', path: location);
    }
    if (a.lane != b.lane) {
      throw FluvieSpecError('Transition clips must be on the same lane', path: location);
    }
    if (a.shared || b.shared) {
      throw FluvieSpecError(
        'Shared heroes use scene transitions; remove sharing before adding a clip transition',
        path: location,
      );
    }
    if (outgoing.containsKey(edge.outgoing) || incoming.containsKey(edge.incoming)) {
      throw FluvieSpecError('A clip can have only one transition at each edge', path: location);
    }
    final left = authored[edge.outgoing]!;
    final right = authored[edge.incoming]!;
    final frames = edge.transition.duration.resolveFrames(
      RelativeDurationGuard(fps, 'A clip transition needs an absolute duration'),
    );
    if (frames <= 0 || edge.transition.duration is RelativeTime) {
      throw FluvieSpecError('A clip transition needs a positive absolute duration', path: location);
    }
    final overlap = left.end - right.start;
    if (left.start >= right.start || overlap < 0 || overlap > frames) {
      throw FluvieSpecError(
        'Transition clip windows must abut or overlap by no more than its duration',
        path: location,
      );
    }
    if (children.any(
      (child) =>
          child.id != null &&
          child.id != edge.outgoing &&
          child.id != edge.incoming &&
          child.isClip &&
          child.lane == a.lane &&
          authored[child.id]!.start > left.start &&
          authored[child.id]!.start < right.start,
    )) {
      throw FluvieSpecError('Transition clips must be adjacent on their lane', path: location);
    }
    outgoing[edge.outgoing] = edge;
    incoming[edge.incoming] = edge;
  }
  final windows = <String, ({int start, int end})>{};
  final blends = <ElementTransitionWindow>[];
  for (final root in outgoing.keys.where((id) => !incoming.containsKey(id))) {
    final ids = [root];
    final edges = <ElementTransitionSpec>[];
    var id = root;
    while (outgoing.containsKey(id)) {
      final edge = outgoing[id]!;
      edges.add(edge);
      ids.add(edge.incoming);
      id = edge.incoming;
    }
    final offsets = _offsets(
      fps: fps,
      durations: [for (final id in ids) Time.frames(authored[id]!.end - authored[id]!.start)],
      transitions: [for (final edge in edges) edge.transition],
      sceneIds: ids,
      path: path,
    );
    final origin = authored[root]!.start;
    for (var i = 0; i < ids.length; i++) {
      final start = origin + offsets.startFrames[i];
      windows[ids[i]] = (start: start, end: start + offsets.durationFrames[i]);
    }
    for (var i = 0; i < edges.length; i++) {
      final edge = edges[i];
      final start = windows[edge.incoming]!.start;
      final end = start + offsets.transitionFrames[i];
      blends.add(
        ElementTransitionWindow(
          outgoing: edge.outgoing,
          incoming: edge.incoming,
          start: start,
          end: end,
          transition: edge.transition,
          holdFrame: edge.transition.overlap ? null : windows[edge.outgoing]!.end - 1,
        ),
      );
    }
  }
  return ElementTransitionLayout(Map.unmodifiable(windows), List.unmodifiable(blends));
}

SceneOffsets _offsets({
  required int fps,
  required List<Time> durations,
  required List<Transition> transitions,
  required List<String> sceneIds,
  required List<String> path,
}) {
  try {
    return resolveSceneOffsets(
      fps: fps,
      durations: durations,
      transitions: transitions,
      sceneIds: sceneIds,
    );
  } on FluvieTimingError catch (error) {
    throw FluvieSpecError(error.message, path: [...path, 'transitions']);
  }
}
