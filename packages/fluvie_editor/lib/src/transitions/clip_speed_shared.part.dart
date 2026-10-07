part of 'clip_speed_edit.dart';

/// Computes each independent source clock on a detached calculation document,
/// then restores continuity identities in one validated command. Nothing from
/// the detached document enters history or reaches the mounted preview.
VideoLaneEdit _sharedSpeedEdited(
  EditorDocument document,
  String id,
  VideoLaneEdit Function(EditorDocument local, String member) edit, {
  String? mergeGroup,
}) {
  final ids = document.sharedChainIds(id);
  final originals = {for (final member in ids) member: document.elementJson(member)!};
  final detached = document.splitSharedMembers({
    for (final entry in originals.entries) entry.key: {...entry.value}..remove('shared'),
  }, const {});
  final replacements = <String, Map<String, Object?>>{};
  for (final member in ids) {
    final result = edit(detached, member);
    if (result.command == null) {
      return VideoLaneEdit.refused('Shared clip $member: ${result.note}');
    }
    final updated = result.command!.apply(detached).elementJson(member)!;
    final original = originals[member]!;
    replacements[member] = {
      ...updated,
      'shared': original['shared'],
      // A closed trim is unchanged by speed edits; retain its exact authored
      // source-frame phase, including decimal seconds and unit spelling.
      if (readClipTrimSeconds(original) case final trim? when !trim.toOpen)
        'trim': original['trim'],
    };
  }
  final command = ReplaceSharedMembersCommand(members: replacements, mergeGroup: mergeGroup);
  try {
    command.apply(document);
    return VideoLaneEdit.command(command);
  } on Object catch (error) {
    return VideoLaneEdit.refused('Shared clip speed refused: $error');
  }
}
