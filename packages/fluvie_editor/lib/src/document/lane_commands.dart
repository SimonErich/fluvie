part of 'editor_command.dart';

/// Updates a declared lane's name, height, lock, mute or gain.
final class SetLaneCommand extends EditorCommand {
  /// Applies [patch] to lane [id].
  const SetLaneCommand({required this.id, required this.patch, this.mergeGroup});

  /// The stable lane identity.
  final String id;

  /// Changed lane fields; null removes an optional field.
  final Map<String, Object?> patch;

  /// Optional continuous gesture identity.
  final String? mergeGroup;
  @override
  EditorDocument apply(EditorDocument document) => document.updateLane(id, patch);
  @override
  String get label => 'Edit lane';
  @override
  Set<String> get affectedIds => const {};
  @override
  String? get mergeKey => mergeGroup == null ? null : 'lane:$id:$mergeGroup';
}

/// Reorders a lane and its assigned elements' paint order together.
final class ReorderLaneCommand extends EditorCommand {
  /// Moves lane [id] to the declared lane index [to].
  const ReorderLaneCommand({required this.id, required this.to});

  /// The lane to reorder.
  final String id;

  /// Its destination index, after removing it from its old position.
  final int to;
  @override
  EditorDocument apply(EditorDocument document) => document.reorderLane(id, to);
  @override
  String get label => 'Reorder lane';
  @override
  Set<String> get affectedIds => const {};
}

/// Assigns material to a lane without replacing a stale copy of its timing.
final class SetElementLaneCommand extends EditorCommand {
  /// Assigns [id] to [lane], or to its implicit row when null.
  const SetElementLaneCommand({required this.id, required this.lane, this.mergeGroup});

  /// The element identity.
  final String id;

  /// Target declared lane, or null.
  final String? lane;

  /// Optional drag identity.
  final String? mergeGroup;
  @override
  EditorDocument apply(EditorDocument document) {
    var next = document;
    for (final member in document.sharedChainIds(id)) {
      final element = next.elementJson(member)!;
      if (lane == null) {
        element.remove('lane');
      } else {
        element['lane'] = lane;
      }
      next = next.replaceElement(member, element);
    }
    final index = document.spec.lanes.indexWhere((item) => item.id == lane);
    return lane == null || index < 0 ? next : next.reorderLane(lane!, index);
  }

  @override
  String get label => 'Move to lane';
  @override
  Set<String> get affectedIds => {id};
  @override
  String? get mergeKey => mergeGroup == null ? null : 'lane:$mergeGroup:$id';
}

/// Deletes a lane while leaving all its clips and audio in the document.
final class RemoveLaneCommand extends EditorCommand {
  /// Deletes lane [id].
  const RemoveLaneCommand({required this.id});

  /// The lane identity.
  final String id;
  @override
  EditorDocument apply(EditorDocument document) => document.removeLane(id);
  @override
  String get label => 'Delete lane';
  @override
  Set<String> get affectedIds => const {};
}
