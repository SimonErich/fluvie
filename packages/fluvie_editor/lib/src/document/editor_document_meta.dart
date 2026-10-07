part of 'editor_document.dart';

/// The editor-block metadata writers: per-element and per-slide channels.
/// Neither is render-affecting (the digest excludes the `editor` block).
extension EditorDocumentMeta on EditorDocument {
  /// Writes the editor-block metadata for element [id] (merging over what
  /// was there; a null value removes its key).
  EditorDocument setElementMeta(String id, Map<String, Object?> meta) => _mutate((json) {
    final editor =
        (json['editor'] ??= <String, Object?>{'editorSchema': 1}) as Map<String, Object?>;
    final elements = (editor['elements'] ??= <String, Object?>{}) as Map<String, Object?>;
    final existing = elements[id];
    elements[id] = {
      if (existing is Map<String, Object?>) ...existing,
      ..._deepCopy(meta),
    }..removeWhere((_, value) => value == null);
  });

  /// Writes the editor-block metadata for slide [index] (merging over what
  /// was there; a null value removes its key). Manual guides and section
  /// markers live here. Throws a [RangeError] for an index the deck does
  /// not have.
  EditorDocument setSceneMeta(int index, Map<String, Object?> meta) => _mutate((json) {
    RangeError.checkValidIndex(index, json['scenes']! as List<Object?>, 'index');
    final editor =
        (json['editor'] ??= <String, Object?>{'editorSchema': 1}) as Map<String, Object?>;
    final scenes = (editor['scenes'] ??= <String, Object?>{}) as Map<String, Object?>;
    final existing = scenes['$index'];
    scenes['$index'] = {
      if (existing is Map<String, Object?>) ...existing,
      ..._deepCopy(meta),
    }..removeWhere((_, value) => value == null);
  });
}
