part of 'editor_document.dart';

/// The document's effect mutations: editing one entry of an element's
/// `effects` list. Like every mutation, each returns a new document
/// revalidated through the spec parser.
extension EditorDocumentEffects on EditorDocument {
  /// Merges [patch] into effect [index] of element [id]'s `effects` list; a
  /// `null` value removes its key (collapsing a keyframed parameter back to
  /// silence, for example).
  ///
  /// Throws a [RangeError] when the element has no effect at [index] and an
  /// [ArgumentError] for an unknown id.
  EditorDocument updateEffect(String id, int index, Map<String, Object?> patch) => _mutate(
    (json) => _withElement(json, id, (element) {
      final effects = element['effects'];
      final list = effects is List ? effects : const <Object?>[];
      RangeError.checkValidIndex(index, list, 'index');
      final effect = {...(list[index]! as Map).cast<String, Object?>()};
      for (final entry in patch.entries) {
        if (entry.value == null) {
          effect.remove(entry.key);
        } else {
          effect[entry.key] = _copyValue(entry.value!);
        }
      }
      final next = [...list]..[index] = effect;
      return {...element, 'effects': next};
    }),
  );

  /// Appends [effect] to element [id]'s `effects` list, creating the list
  /// when the element had none. Throws an [ArgumentError] for an unknown id.
  EditorDocument addEffect(String id, Map<String, Object?> effect) => _mutate(
    (json) => _withElement(json, id, (element) {
      final effects = element['effects'];
      final list = effects is List ? effects : const <Object?>[];
      return {
        ...element,
        'effects': [...list, _deepCopy(effect)],
      };
    }),
  );

  /// Removes effect [index] of element [id]'s `effects` list; removing the
  /// last one drops the `effects` key itself.
  ///
  /// Throws a [RangeError] when the element has no effect at [index] and an
  /// [ArgumentError] for an unknown id.
  EditorDocument removeEffect(String id, int index) => _mutate(
    (json) => _withElement(json, id, (element) {
      final effects = element['effects'];
      final list = effects is List ? effects : const <Object?>[];
      RangeError.checkValidIndex(index, list, 'index');
      final next = [...list]..removeAt(index);
      final trimmed = {...element}..remove('effects');
      return next.isEmpty ? trimmed : {...trimmed, 'effects': next};
    }),
  );

  /// Moves effect [from] of element [id]'s `effects` list to index [to],
  /// keeping every other entry in order.
  ///
  /// Throws a [RangeError] when either index is out of the list and an
  /// [ArgumentError] for an unknown id.
  EditorDocument reorderEffect(String id, int from, int to) => _mutate(
    (json) => _withElement(json, id, (element) {
      final effects = element['effects'];
      final list = effects is List ? effects : const <Object?>[];
      RangeError.checkValidIndex(from, list, 'from');
      RangeError.checkValidIndex(to, list, 'to');
      final next = [...list];
      final moved = next.removeAt(from);
      next.insert(to, moved);
      return {...element, 'effects': next};
    }),
  );
}
