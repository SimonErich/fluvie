part of 'editor_command.dart';

/// Appends one audio track to the video's `audio` list, or to a scene's —
/// how the video timeline's add-track picker lands.
final class AddAudioTrackCommand extends EditorCommand {
  /// Appends [track] at the video level, or on scene [scene] when given.
  const AddAudioTrackCommand({required this.track, this.scene});

  /// The track JSON to append (`{kind, source, ...}`).
  final Map<String, Object?> track;

  /// The owning scene, or null for the video-level list.
  final int? scene;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.addAudioTrack(scene: scene, track: track);

  @override
  String get label => 'Add audio track';

  @override
  Set<String> get affectedIds => const {};
}

/// Patches one audio track — volume, fades, loop, trim, or an sfx `at` —
/// where every audio lane and inspector edit lands.
final class SetAudioTrackCommand extends EditorCommand {
  /// Merges [patch] into track [index] of the video-level list (or scene
  /// [scene]'s); a null value removes its key. A non-null [mergeGroup]
  /// coalesces a drag's stream of edits into one undo step.
  const SetAudioTrackCommand({
    required this.index,
    required this.patch,
    this.scene,
    this.mergeGroup,
  });

  /// The track's position in its owner's `audio` list.
  final int index;

  /// The keys to merge (null values remove).
  final Map<String, Object?> patch;

  /// The owning scene, or null for the video-level list.
  final int? scene;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.updateAudioTrack(scene: scene, index: index, patch: patch);

  @override
  String get label => 'Edit audio track';

  @override
  Set<String> get affectedIds => const {};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'audio:$mergeGroup:${scene ?? 'v'}:$index';
}

/// Removes one audio track from its owner's `audio` list.
final class RemoveAudioTrackCommand extends EditorCommand {
  /// Removes track [index] of the video-level list (or scene [scene]'s).
  const RemoveAudioTrackCommand({required this.index, this.scene});

  /// The track's position in its owner's `audio` list.
  final int index;

  /// The owning scene, or null for the video-level list.
  final int? scene;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.removeAudioTrack(scene: scene, index: index);

  @override
  String get label => 'Remove audio track';

  @override
  Set<String> get affectedIds => const {};
}

/// Moves one audio track within its owner's `audio` list (the mix order).
final class ReorderAudioTrackCommand extends EditorCommand {
  /// Moves track [from] to position [to] of the video-level list (or scene
  /// [scene]'s).
  const ReorderAudioTrackCommand({required this.from, required this.to, this.scene});

  /// The track's current position.
  final int from;

  /// The position it moves to.
  final int to;

  /// The owning scene, or null for the video-level list.
  final int? scene;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.reorderAudioTrack(scene: scene, from: from, to: to);

  @override
  String get label => 'Reorder audio tracks';

  @override
  Set<String> get affectedIds => const {};
}

/// Writes the generated automation onto every target as one undo step.
final class DuckAudioTracksCommand extends EditorCommand {
  /// Track addresses and their plain automation JSON.
  const DuckAudioTracksCommand({
    required this.envelopes,
    this.clipEnvelopes = const {},
    this.label = 'Duck audio lane',
  });

  /// Each target's scene/index plus replacement automation.
  final List<({int? scene, int index, Map<String, Object?> automation})> envelopes;

  /// Embedded clip ids mapped to replacement volume automation.
  final Map<String, Map<String, Object?>> clipEnvelopes;

  @override
  EditorDocument apply(EditorDocument document) {
    var result = document;
    for (final target in envelopes) {
      result = result.updateAudioTrack(
        scene: target.scene,
        index: target.index,
        patch: {'automation': target.automation.isEmpty ? null : target.automation},
      );
    }
    for (final entry in clipEnvelopes.entries) {
      final raw = result.elementJson(entry.key);
      if (raw == null) continue;
      if (entry.value.isEmpty) {
        raw.remove('automation');
      } else {
        raw['automation'] = entry.value;
      }
      result = result.editSharedContent(entry.key, raw);
    }
    return result;
  }

  @override
  final String label;

  @override
  Set<String> get affectedIds => clipEnvelopes.keys.toSet();
}
