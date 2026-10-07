part of 'editor_command.dart';

/// Splits a shared timeline chain while retaining scene/group memberships and
/// every member's geometry. Each half receives its own continuity identity.
final class SplitSharedChainCommand extends EditorCommand {
  /// Replaces existing [members] and inserts [tails] beside their head ids.
  const SplitSharedChainCommand({
    required this.members,
    required this.tails,
    required this.tailPrimaryId,
    this.mergeGroup,
  });

  /// Existing members with their updated windows or continuity identities.
  final Map<String, Map<String, Object?>> members;

  /// Newly split elements keyed by the head they follow.
  final Map<String, Map<String, Object?>> tails;

  /// Stable element identity of the new right-hand chain's first member.
  final String tailPrimaryId;

  /// Drag/compound-edit coalescing identity.
  final String? mergeGroup;
  @override
  EditorDocument apply(EditorDocument document) => document.splitSharedMembers(members, tails);
  @override
  String get label => 'Razor shared chain';
  @override
  Set<String> get affectedIds => {
    ...members.keys,
    for (final tail in tails.values) tail['id']! as String,
  };
  @override
  String? get mergeKey => mergeGroup == null ? null : 'razor:$mergeGroup';
}

/// Splits one element into two at a cut: [id] keeps the head and [tailId]
/// takes the tail.
///
/// One command rather than a replace plus an insert, so a cut is one undo
/// step by construction rather than by two steps agreeing on a merge key. The
/// tail lands directly above the head in z-order, where the eye expects the
/// later half of the same thing to be.
final class RazorElementCommand extends EditorCommand {
  /// Replaces [id] with [head] and inserts [tail] as [tailId] beside it.
  const RazorElementCommand({
    required this.id,
    required this.tailId,
    required this.head,
    required this.tail,
    this.mergeGroup,
  });

  /// The element being split; it keeps its identity and its z-position.
  final String id;

  /// The new element's identity, minted before the command so redo stays
  /// deterministic.
  final String tailId;

  /// The head's full JSON.
  final Map<String, Object?> head;

  /// The tail's full JSON (its `id` key is overridden by [tailId]).
  final Map<String, Object?> tail;

  /// The coalescing group, or null for a standalone step. One razor across
  /// several selected bars is one cut, so it is one step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.razorElement(id, tailId, head, tail);

  @override
  String get label => 'Razor $id';

  @override
  Set<String> get affectedIds => {id, tailId};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'razor:$mergeGroup';
}
