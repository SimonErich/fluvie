part of 'editor_command.dart';

/// Replaces shared members atomically without copying one member's source
/// clock or geometry onto the others.
final class ReplaceSharedMembersCommand extends EditorCommand {
  /// Stores the complete replacement of each existing member.
  const ReplaceSharedMembersCommand({
    required this.members,
    this.label = 'Change shared clip speed',
    this.mergeGroup,
  });

  /// Per-member JSON preserving its identity, source phase and holding list.
  final Map<String, Map<String, Object?>> members;

  /// Coalesces all updates in one shared-content drag.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.splitSharedMembers(members, const {});

  @override
  final String label;

  @override
  Set<String> get affectedIds => members.keys.toSet();

  @override
  String? get mergeKey => mergeGroup == null ? null : 'shared:$label:$mergeGroup';
}
