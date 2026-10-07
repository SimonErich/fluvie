part of 'editor_document.dart';

/// The deck's scene-level structural mutations: add, remove, reorder, and
/// duplicate a slide, plus the scene- and deck-level patch merges. Every
/// method deep-copies, applies one change, revalidates through the spec
/// parser, and returns a new document — the substrate slide commands and
/// undo build on.
extension EditorDocumentScenes on EditorDocument {
  /// Adds [scene] (appended, or at [at]). Per-slide editor metadata keeps
  /// following its slide; a non-empty [meta] becomes the new slide's editor
  /// metadata in the same step (the slide-paste payload).
  EditorDocument addScene(Map<String, Object?> scene, {int? at, Map<String, Object?>? meta}) =>
      _mutate((json) {
        final scenes = json['scenes']! as List<Object?>;
        final position = at ?? scenes.length;
        scenes.insert(position, _deepCopy(scene));
        _remapSceneMeta(json, (index) => _insertedAt(index, position));
        if (meta == null || meta.isEmpty) return;
        final editor =
            (json['editor'] ??= <String, Object?>{'editorSchema': 1}) as Map<String, Object?>;
        final sceneMeta = (editor['scenes'] ??= <String, Object?>{}) as Map<String, Object?>;
        sceneMeta['$position'] = _deepCopy(meta);
      });

  /// Removes scene [index] (its editor metadata goes with it). A deck is
  /// never empty: removing the last scene throws a [StateError].
  EditorDocument removeScene(int index) => _mutate((json) {
    final scenes = json['scenes']! as List<Object?>;
    if (scenes.length == 1) {
      throw StateError('A deck needs at least one slide.');
    }
    scenes.removeAt(index);
    _remapSceneMeta(json, (meta) => _removedAt(meta, index));
  });

  /// Moves scene [from] to position [to]. Per-slide editor metadata keeps
  /// following its slide.
  EditorDocument reorderScene(int from, int to) => _mutate((json) {
    final scenes = json['scenes']! as List<Object?>;
    scenes.insert(to, scenes.removeAt(from));
    _remapSceneMeta(json, (index) => _movedTo(index, from, to));
  });

  /// A deep copy of scene [index] with every element id re-minted (group
  /// children included) — the duplicate-slide payload for `AddSceneCommand`.
  /// Ids stay unique across the whole document and within the copy.
  Map<String, Object?> duplicatedScene(int index) {
    final copy = _deepCopy(_scene(index));
    final used = _usedIds(_json);
    for (final walked in _walkScene(copy)) {
      walked.element['id'] = _mintId(used);
    }
    return copy;
  }

  /// Merges [patch] into scene [index]'s JSON; a null value removes its
  /// key (clearing a background, for example).
  EditorDocument updateScene(int index, Map<String, Object?> patch) => _mutate((json) {
    final scene = (json['scenes']! as List<Object?>)[index]! as Map<String, Object?>;
    for (final entry in patch.entries) {
      if (entry.value == null) {
        scene.remove(entry.key);
      } else {
        scene[entry.key] = _copyValue(entry.value!);
      }
    }
  });

  /// Merges [patch] into the deck-level keys (size, fps, and friends).
  /// Throws an [ArgumentError] for `scenes` or `editor` — those have their
  /// own mutations.
  EditorDocument updateVideo(Map<String, Object?> patch) => _mutate((json) {
    for (final entry in patch.entries) {
      if (entry.key == 'scenes' || entry.key == 'editor') {
        throw ArgumentError.value(entry.key, 'patch', 'Use the dedicated mutations');
      }
      if (entry.value == null) {
        json.remove(entry.key);
      } else {
        json[entry.key] = _copyValue(entry.value!);
      }
    }
  });
}

/// A deep copy of any JSON value (patches may carry maps and lists).
Object _copyValue(Object value) => switch (value) {
  Map<String, Object?>() => _deepCopy(value),
  List<Object?>() => jsonDecode(jsonEncode(value)) as Object,
  _ => value,
};
