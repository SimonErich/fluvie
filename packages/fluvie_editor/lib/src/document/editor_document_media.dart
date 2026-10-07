part of 'editor_document.dart';

/// The document's media store (`editor.media`) and the deck-level metadata
/// channel (`editor.deck`). Both live in the editor block, so the render
/// digest excludes them.
extension EditorDocumentMedia on EditorDocument {
  /// The imported media the document tracks, in import order.
  List<MediaStoreEntry> get mediaEntries => [
    for (final raw in _mediaList(_json))
      if (raw is Map<String, Object?>) MediaStoreEntry.fromJson(_deepCopy(raw)),
  ];

  /// A fresh `media-N` id past every held entry.
  String nextMediaId() {
    var highest = 0;
    for (final entry in mediaEntries) {
      final n = int.tryParse(entry.id.replaceFirst('media-', ''));
      if (n != null && n > highest) highest = n;
    }
    return 'media-${highest + 1}';
  }

  /// Appends [entry] to the store.
  ///
  /// Throws an [ArgumentError] when an entry with the same id is already
  /// held.
  EditorDocument addMediaEntry(MediaStoreEntry entry) {
    if (mediaEntries.any((held) => held.id == entry.id)) {
      throw ArgumentError.value(entry.id, 'entry', 'the store already holds this id');
    }
    return _mutate((json) {
      final editor =
          (json['editor'] ??= <String, Object?>{'editorSchema': 1}) as Map<String, Object?>;
      ((editor['media'] ??= <Object?>[]) as List<Object?>).add(_deepCopy(entry.toJson()));
    });
  }

  /// Updates one imported asset's metadata without changing its store position.
  EditorDocument replaceMediaEntry(MediaStoreEntry entry) {
    final index = mediaEntries.indexWhere((held) => held.id == entry.id);
    if (index < 0) throw ArgumentError.value(entry.id, 'id', 'the store holds no such entry');
    return _mutate((json) => _mediaList(json)[index] = _deepCopy(entry.toJson()));
  }

  /// Removes the entry with [id] from the store.
  ///
  /// Throws an [ArgumentError] when no entry has that id.
  EditorDocument removeMediaEntry(String id) {
    if (!mediaEntries.any((held) => held.id == id)) {
      throw ArgumentError.value(id, 'id', 'the store holds no such entry');
    }
    return _mutate(
      (json) => _mediaList(
        json,
      ).removeWhere((raw) => raw is Map<String, Object?> && raw['id'] == id),
    );
  }

  /// The deck-level editor metadata (`editor.deck`): warning suppressions and
  /// friends. Empty when none was written.
  Map<String, Object?> get deckMeta {
    final editor = _json['editor'];
    if (editor is! Map<String, Object?>) return const {};
    final deck = editor['deck'];
    return deck is Map<String, Object?> ? _deepCopy(deck) : const {};
  }

  /// Writes the deck-level editor metadata, merging over what was there; a
  /// null value removes its key.
  EditorDocument setDeckMeta(Map<String, Object?> meta) => _mutate((json) {
    final editor =
        (json['editor'] ??= <String, Object?>{'editorSchema': 1}) as Map<String, Object?>;
    final existing = editor['deck'];
    editor['deck'] = {
      if (existing is Map<String, Object?>) ...existing,
      ..._deepCopy(meta),
    }..removeWhere((_, value) => value == null);
  });
}

List<Object?> _mediaList(Map<String, Object?> json) {
  final editor = json['editor'];
  if (editor is! Map<String, Object?>) return const [];
  final media = editor['media'];
  return media is List<Object?> ? media : const [];
}
