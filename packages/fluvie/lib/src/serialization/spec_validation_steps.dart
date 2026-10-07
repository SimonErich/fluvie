part of 'spec_validation.dart';

/// The keys a step entry reads.
const Set<String> _stepEntryKeys = {'elements', 'notes'};

/// The keys a notes object reads.
const Set<String> _notesKeys = {'text', 'highlights'};

/// Checks a scene's `steps` and `notes` per the steps-and-notes ADR: `steps`
/// is a list of objects, every `elements` id names a child of this scene, no
/// id repeats across steps, and every notes object (scene-level or per-step)
/// carries only a string `text` and a list-of-strings `highlights`.
void _checkStepsAndNotes(
  Map<String, Object?> scene,
  List<String> scenePath,
  List<FluvieSpecWarning> out,
) {
  final notes = scene['notes'];
  if (notes != null) _checkNotes(notes, [...scenePath, 'notes'], out);
  final steps = scene['steps'];
  if (steps == null) return;
  if (steps is! List) {
    out.add(
      FluvieSpecWarning(
        'Expected "steps" to be a list of step objects',
        path: [...scenePath, 'steps'],
      ),
    );
    return;
  }
  final childIds = _childIds(scene);
  final claimed = <String>{};
  for (var i = 0; i < steps.length; i++) {
    _checkStep(steps[i], [...scenePath, 'steps', '$i'], childIds, claimed, out);
  }
}

void _checkStep(
  Object? step,
  List<String> path,
  Set<String> childIds,
  Set<String> claimed,
  List<FluvieSpecWarning> out,
) {
  if (step is! Map<String, Object?>) {
    out.add(FluvieSpecWarning('Expected a step object with an "elements" list', path: path));
    return;
  }
  _checkKeys(step, _stepEntryKeys, 'a step', path, out);
  final stepNotes = step['notes'];
  if (stepNotes != null) _checkNotes(stepNotes, [...path, 'notes'], out);
  final elements = step['elements'];
  if (elements is! List || elements.isEmpty) {
    out.add(
      FluvieSpecWarning('A step needs a non-empty "elements" list of scene child ids', path: path),
    );
    return;
  }
  for (var i = 0; i < elements.length; i++) {
    final id = elements[i];
    final idPath = [...path, 'elements', '$i'];
    if (id is! String) {
      out.add(FluvieSpecWarning('Expected a child id string', path: idPath));
      continue;
    }
    if (!childIds.contains(id)) {
      out.add(
        FluvieSpecWarning(
          '"$id" names no child of this scene; a step reveals children by their "id"',
          path: idPath,
        ),
      );
    }
    if (!claimed.add(id)) {
      out.add(
        FluvieSpecWarning(
          '"$id" already belongs to an earlier step; an id appears in at most one step',
          path: idPath,
        ),
      );
    }
  }
}

/// The `id` of every scene child that carries one. Fills count too: adoption
/// makes them scene children, so a step may reveal a fill by its id.
Set<String> _childIds(Map<String, Object?> scene) {
  final children = scene['children'];
  final fills = scene['fills'];
  return {
    if (children is List)
      for (final child in children)
        if (child is Map<String, Object?> && child['id'] is String) child['id']! as String,
    if (fills is Map<String, Object?>)
      for (final fill in fills.values)
        if (fill is Map<String, Object?> && fill['id'] is String) fill['id']! as String,
  };
}

void _checkNotes(Object? notes, List<String> path, List<FluvieSpecWarning> out) {
  if (notes is! Map<String, Object?>) {
    out.add(
      FluvieSpecWarning('Expected a notes object with "text" and/or "highlights"', path: path),
    );
    return;
  }
  _checkKeys(notes, _notesKeys, 'notes', path, out);
  final text = notes['text'];
  if (text != null && text is! String) {
    out.add(FluvieSpecWarning('Expected "text" to be a string', path: [...path, 'text']));
  }
  final highlights = notes['highlights'];
  if (highlights == null) return;
  if (highlights is! List) {
    out.add(
      FluvieSpecWarning(
        'Expected "highlights" to be a list of strings',
        path: [...path, 'highlights'],
      ),
    );
    return;
  }
  for (var i = 0; i < highlights.length; i++) {
    if (highlights[i] is! String) {
      out.add(
        FluvieSpecWarning('Expected a highlight string', path: [...path, 'highlights', '$i']),
      );
    }
  }
}
