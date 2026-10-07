part of 'editor_command.dart';

/// The canonical form of a notes object: an empty `text` drops its key, an
/// empty `highlights` list drops its key, and a notes object left with
/// nothing is `null` — clearing all content removes the key entirely, so
/// the document never carries `{}` residue.
Map<String, Object?>? _canonicalNotes(Map<String, Object?>? notes) {
  if (notes == null) return null;
  final text = notes['text'];
  final highlights = notes['highlights'];
  final canonical = {
    if (text is String && text.isNotEmpty) 'text': text,
    if (highlights is List && highlights.isNotEmpty) 'highlights': [...highlights],
  };
  return canonical.isEmpty ? null : canonical;
}

/// Writes a slide's speaker notes (the scene-level `notes` object) — the
/// default every build step inherits.
final class SetSceneNotesCommand extends EditorCommand {
  /// Writes [notes] onto slide [index], canonicalized: empty text and
  /// empty highlights drop their keys, and a content-free object (or
  /// `null`) removes the `notes` key entirely.
  const SetSceneNotesCommand({required this.index, required this.notes});

  /// The slide whose notes change.
  final int index;

  /// The new notes object (`text` and `highlights`), or null to remove it.
  final Map<String, Object?>? notes;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.updateScene(index, {'notes': _canonicalNotes(notes)});

  @override
  String get label => 'Edit speaker notes';

  @override
  Set<String> get affectedIds => const {};
}

/// Writes one build step's per-step notes override (`steps[step].notes`):
/// its text replaces the scene text while the step is active, its
/// highlights append to the scene's.
final class SetStepNotesCommand extends EditorCommand {
  /// Writes [notes] onto listed step [step] of slide [index] (0-based into
  /// the scene's `steps` list), canonicalized like the scene command: a
  /// content-free object (or `null`) removes the step's `notes` key, and
  /// the step keeps its `elements`.
  const SetStepNotesCommand({required this.index, required this.step, required this.notes});

  /// The slide whose steps carry the notes.
  final int index;

  /// The listed step being annotated (0-based into the `steps` list).
  final int step;

  /// The new notes object (`text` and `highlights`), or null to remove it.
  final Map<String, Object?>? notes;

  @override
  EditorDocument apply(EditorDocument document) {
    final steps = [...(document.sceneJson(index)['steps'] as List? ?? const [])];
    final entry = {...steps[step]! as Map<String, Object?>};
    final canonical = _canonicalNotes(notes);
    if (canonical == null) {
      entry.remove('notes');
    } else {
      entry['notes'] = canonical;
    }
    steps[step] = entry;
    return document.updateScene(index, {'steps': steps});
  }

  @override
  String get label => 'Edit step notes';

  @override
  Set<String> get affectedIds => const {};
}
