part of 'scene_spec.dart';

/// One build step of a scene: the child ids it reveals, plus optional
/// per-step speaker [notes].
///
/// Steps are presentation metadata over a scene's flat `children` list — the
/// `steps` list order is the step order, every id names a child of the same
/// scene, an id appears in at most one step, and children named by no step
/// are step 0. Fluvie stores, validates, and round-trips steps; it never
/// reads them while rendering ([SceneSpec.build] ignores them). Only
/// `package:fluvie_presenter` interprets them, through `deckFromSpec`.
final class StepSpec {
  /// Creates a step revealing [elements], with optional per-step [notes].
  StepSpec({required this.elements, this.notes});

  /// Reads a step from [json].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a missing or empty
  /// `elements` list, a non-string id, or malformed `notes`.
  factory StepSpec.fromJson(Map<String, Object?> json, {List<String> path = const []}) {
    final elementsRaw = json['elements'];
    if (elementsRaw is! List || elementsRaw.isEmpty) {
      throw FluvieSpecError(
        'A step needs a non-empty "elements" list of scene child ids',
        path: [...path, 'elements'],
      );
    }
    final elements = <String>[];
    for (var i = 0; i < elementsRaw.length; i++) {
      final id = elementsRaw[i];
      if (id is! String) {
        throw FluvieSpecError('Expected a child id string', path: [...path, 'elements', '$i']);
      }
      elements.add(id);
    }
    final notes = json['notes'];
    return StepSpec(
      elements: elements,
      notes: notes == null
          ? null
          : NotesSpec.fromJson(_object(notes, [...path, 'notes']), path: [...path, 'notes']),
    );
  }

  /// The ids of the scene children this step reveals; never empty.
  final List<String> elements;

  /// The per-step notes override, or null to inherit the scene notes. Its
  /// text replaces the scene text while the step is active; its highlights
  /// append to the scene's.
  final NotesSpec? notes;

  /// The JSON form of this step.
  Map<String, Object?> toJson() => {
    'elements': elements,
    if (notes != null) 'notes': notes!.toJson(),
  };
}

/// Speaker notes, for the person presenting: the full prose [text] and the
/// glanceable [highlights] — the data twin of the presenter's
/// `SpeakerNotes` widget. Stored and round-tripped by fluvie, never read
/// while rendering.
final class NotesSpec {
  /// Creates notes with an optional [text] and [highlights] list.
  NotesSpec({this.text, this.highlights = const []});

  /// Reads a notes object from [json].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a non-string `text`
  /// or a `highlights` value that is not a list of strings.
  factory NotesSpec.fromJson(Map<String, Object?> json, {List<String> path = const []}) {
    final text = json['text'];
    if (text != null && text is! String) {
      throw FluvieSpecError('Expected "text" to be a string', path: [...path, 'text']);
    }
    final highlightsRaw = json['highlights'];
    final highlights = <String>[];
    if (highlightsRaw is List) {
      for (var i = 0; i < highlightsRaw.length; i++) {
        final highlight = highlightsRaw[i];
        if (highlight is! String) {
          throw FluvieSpecError(
            'Expected a highlight string',
            path: [...path, 'highlights', '$i'],
          );
        }
        highlights.add(highlight);
      }
    } else if (highlightsRaw != null) {
      throw FluvieSpecError(
        'Expected "highlights" to be a list of strings',
        path: [...path, 'highlights'],
      );
    }
    return NotesSpec(text: text as String?, highlights: highlights);
  }

  /// What to say — the full prose, or null when only highlights matter.
  final String? text;

  /// The quick-glance bullets a speaker view lists down its side.
  final List<String> highlights;

  /// The JSON form of these notes.
  Map<String, Object?> toJson() => {
    if (text != null) 'text': text,
    if (highlights.isNotEmpty) 'highlights': highlights,
  };
}

/// Decodes a scene's `steps` list, or `const []` when [raw] is absent.
List<StepSpec> _decodeSteps(Object? raw, List<String> path) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw FluvieSpecError('Expected "steps" to be a list of step objects', path: path);
  }
  return [
    for (var i = 0; i < raw.length; i++)
      StepSpec.fromJson(_object(raw[i], [...path, '$i']), path: [...path, '$i']),
  ];
}
