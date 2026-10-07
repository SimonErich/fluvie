part of 'editor_document.dart';

/// The document's audio-track mutations: the `audio` lists on the video and
/// on each scene, edited as raw JSON and revalidated through the spec
/// parser like every mutation.
///
/// A `scene` of `null` addresses the video-level list; an index addresses
/// that scene's list. Placement in time stays with the owner (the spec's
/// law): a video track spans the video, a scene track starts with its
/// scene.
extension EditorDocumentAudio on EditorDocument {
  /// The audio tracks of the video (`scene` null) or of scene [scene], as
  /// deep-copied JSON in mix order. Empty when none are declared.
  List<Map<String, Object?>> audioTracksJson({int? scene}) {
    final owner = scene == null ? _json : _scene(scene);
    final audio = owner['audio'];
    if (audio is! List) return const [];
    return [for (final track in audio) _deepCopy(track! as Map<String, Object?>)];
  }

  /// Appends [track] to the owner's `audio` list, creating the list when
  /// the owner had none.
  EditorDocument addAudioTrack({required Map<String, Object?> track, int? scene}) =>
      _mutate((json) => _audioListOf(json, scene).add(_deepCopy(track)));

  /// Merges [patch] into track [index] of the owner's `audio` list; a null
  /// value removes its key. Throws a [RangeError] for an index the list
  /// does not hold.
  EditorDocument updateAudioTrack({
    required int index,
    required Map<String, Object?> patch,
    int? scene,
  }) => _mutate((json) {
    final list = _audioListOf(json, scene);
    RangeError.checkValidIndex(index, list, 'index');
    final track = {...list[index]! as Map<String, Object?>};
    for (final entry in patch.entries) {
      if (entry.value == null) {
        track.remove(entry.key);
      } else {
        track[entry.key] = _copyValue(entry.value!);
      }
    }
    list[index] = track;
  });

  /// Removes track [index] from the owner's `audio` list; an emptied list
  /// drops the `audio` key itself. Throws a [RangeError] for an index the
  /// list does not hold.
  EditorDocument removeAudioTrack({required int index, int? scene}) => _mutate((json) {
    final owner = scene == null ? json : (json['scenes']! as List<Object?>)[scene]! as Map;
    final list = _audioListOf(json, scene);
    RangeError.checkValidIndex(index, list, 'index');
    list.removeAt(index);
    if (list.isEmpty) owner.remove('audio');
  });

  /// Moves track [from] to position [to] within the owner's `audio` list.
  /// Throws a [RangeError] for an index the list does not hold.
  EditorDocument reorderAudioTrack({required int from, required int to, int? scene}) =>
      _mutate((json) {
        final list = _audioListOf(json, scene);
        RangeError.checkValidIndex(from, list, 'from');
        RangeError.checkValidIndex(to, list, 'to');
        list.insert(to, list.removeAt(from));
      });
}

/// The mutable `audio` list of the video (`scene` null) or of scene
/// [scene] inside a working copy, created when absent.
List<Object?> _audioListOf(Map<String, Object?> json, int? scene) {
  final owner = scene == null
      ? json
      : (json['scenes']! as List<Object?>)[scene]! as Map<String, Object?>;
  return (owner['audio'] ??= <Object?>[]) as List<Object?>;
}
