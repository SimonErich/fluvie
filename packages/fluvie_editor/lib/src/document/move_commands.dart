part of 'editor_command.dart';

/// Moves an element into a group — the layers panel's drag into a group's
/// subtree. One undo step; the transform rewrites group-relative so nothing
/// moves on screen, and blocks on both sides re-balance.
final class MoveIntoGroupCommand extends EditorCommand {
  /// Moves [id] into [groupId] at child z-position [at].
  const MoveIntoGroupCommand({required this.id, required this.groupId, required this.at});

  /// The element being moved.
  final String id;

  /// The receiving top-level group.
  final String groupId;

  /// The child z-position the element lands at.
  final int at;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.moveIntoGroup(id, groupId: groupId, at: at);

  @override
  String get label => 'Move $id into group';

  @override
  Set<String> get affectedIds => {id, groupId};
}

/// Moves a top-level element (a group moves whole) to another scene — the
/// video timeline's cross-scene lane drag. One undo step: the element's
/// JSON travels verbatim, its `show` window rewrites relative to the target
/// scene, and its id leaves the source scene's build steps (a step names
/// its own scene's children).
final class MoveElementToSceneCommand extends EditorCommand {
  /// Moves [id] to scene [toScene], windowed to `fromFrames..toFrames`
  /// (scene-relative). A non-null [mergeGroup] coalesces the boundary
  /// crossing with the drag's stream of window writes into one undo step.
  const MoveElementToSceneCommand({
    required this.id,
    required this.toScene,
    required this.fromFrames,
    required this.toFrames,
    this.mergeGroup,
  });

  /// The element changing scenes.
  final String id;

  /// The scene the element lands in.
  final int toScene;

  /// The first frame of the rewritten window, relative to [toScene].
  final int fromFrames;

  /// The rewritten window's exclusive end, relative to [toScene].
  final int toFrames;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.moveElementToScene(
    id,
    toScene: toScene,
    fromFrames: fromFrames,
    toFrames: toFrames,
  );

  @override
  String get label => 'Move $id to slide ${toScene + 1}';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'show:$mergeGroup:$id';
}

/// Moves a group child out to the slide's top level — the layers panel's
/// drag out of a subtree. One undo step through the ungroup promotion math.
final class MoveOutOfGroupCommand extends EditorCommand {
  /// Moves [id] out of [groupId] to top-level z-position [at].
  const MoveOutOfGroupCommand({required this.id, required this.groupId, required this.at});

  /// The child being promoted.
  final String id;

  /// The group being left (named for the history's selection follow).
  final String groupId;

  /// The top-level z-position the element lands at.
  final int at;

  @override
  EditorDocument apply(EditorDocument document) => document.moveOutOfGroup(id, at: at);

  @override
  String get label => 'Move $id out of group';

  @override
  Set<String> get affectedIds => {id, groupId};
}
