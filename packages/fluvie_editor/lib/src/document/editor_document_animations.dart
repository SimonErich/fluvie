part of 'editor_document.dart';

/// The document's animation mutations: editing one entry of an element's
/// `animate` list, and appending a new one. Like every mutation, each
/// returns a new document revalidated through the spec parser.
extension EditorDocumentAnimations on EditorDocument {
  /// Merges [patch] into animation [index] of element [id]'s `animate`
  /// list; a `null` value removes its key (clearing a delay, for example).
  ///
  /// Throws a [RangeError] when the element has no animation at [index]
  /// and an [ArgumentError] for an unknown id.
  EditorDocument updateAnimation(String id, int index, Map<String, Object?> patch) => _mutate(
    (json) => _withElement(json, id, (element) {
      final animate = element['animate'];
      final list = animate is List ? animate : const <Object?>[];
      RangeError.checkValidIndex(index, list, 'index');
      final animation = {...list[index]! as Map<String, Object?>};
      for (final entry in patch.entries) {
        if (entry.value == null) {
          animation.remove(entry.key);
        } else {
          animation[entry.key] = _copyValue(entry.value!);
        }
      }
      final next = [...list]..[index] = animation;
      return {...element, 'animate': next};
    }),
  );

  /// Removes animation [index] of element [id]'s `animate` list; removing
  /// the last one drops the `animate` key itself.
  ///
  /// Throws a [RangeError] when the element has no animation at [index]
  /// and an [ArgumentError] for an unknown id.
  EditorDocument removeAnimation(String id, int index) => _mutate(
    (json) => _withElement(json, id, (element) {
      final animate = element['animate'];
      final list = animate is List ? animate : const <Object?>[];
      RangeError.checkValidIndex(index, list, 'index');
      final next = [...list]..removeAt(index);
      final trimmed = {...element}..remove('animate');
      return next.isEmpty ? trimmed : {...trimmed, 'animate': next};
    }),
  );

  /// Appends [animation] to element [id]'s `animate` list, creating the
  /// list when the element had none. Throws an [ArgumentError] for an
  /// unknown id.
  EditorDocument addAnimation(String id, Map<String, Object?> animation) => _mutate(
    (json) => _withElement(json, id, (element) {
      final animate = element['animate'];
      final list = animate is List ? animate : const <Object?>[];
      return {
        ...element,
        'animate': [...list, _deepCopy(animation)],
      };
    }),
  );
}
