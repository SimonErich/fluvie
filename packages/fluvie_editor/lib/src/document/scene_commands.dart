part of 'editor_command.dart';

/// Adds a slide.
final class AddSceneCommand extends EditorCommand {
  /// Adds [scene] (appended, or at [at]), with optional editor [meta] for
  /// the new slide. [verb] names the step for the undo menu.
  const AddSceneCommand({required this.scene, this.at, this.meta, this.verb = 'Add'});

  /// The scene JSON.
  final Map<String, Object?> scene;

  /// The slide position, or null to append.
  final int? at;

  /// The new slide's editor metadata (a pasted slide's guides), or null.
  final Map<String, Object?>? meta;

  /// What the undo menu calls this ("Add", "Paste").
  final String verb;

  @override
  EditorDocument apply(EditorDocument document) => document.addScene(scene, at: at, meta: meta);

  @override
  String get label => '$verb slide';

  @override
  Set<String> get affectedIds => const {};
}

/// Deletes a slide.
final class RemoveSceneCommand extends EditorCommand {
  /// Removes slide [index].
  const RemoveSceneCommand({required this.index});

  /// The slide being removed.
  final int index;

  @override
  EditorDocument apply(EditorDocument document) => document.removeScene(index);

  @override
  String get label => 'Delete slide';

  @override
  Set<String> get affectedIds => const {};
}

/// Patches a slide's own keys (background, duration, layout).
final class UpdateSceneCommand extends EditorCommand {
  /// Merges [patch] into slide [index]; null values remove their keys. A
  /// non-null [mergeGroup] coalesces a stream (a color drag) into one step.
  const UpdateSceneCommand({required this.index, required this.patch, this.mergeGroup});

  /// The slide being patched.
  final int index;

  /// The keys to merge (null values remove).
  final Map<String, Object?> patch;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.updateScene(index, patch);

  @override
  String get label => 'Edit slide';

  @override
  Set<String> get affectedIds => const {};

  @override
  String? get mergeKey =>
      mergeGroup == null ? null : 'scene:$mergeGroup:$index:${patch.keys.join(',')}';
}

/// Patches the deck-level keys (size, fps).
final class UpdateVideoCommand extends EditorCommand {
  /// Merges [patch] into the deck; null values remove their keys.
  const UpdateVideoCommand({required this.patch, this.mergeGroup});

  /// The keys to merge (null values remove).
  final Map<String, Object?> patch;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.updateVideo(patch);

  @override
  String get label => 'Deck settings';

  @override
  Set<String> get affectedIds => const {};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'video:$mergeGroup:${patch.keys.join(',')}';
}

/// Writes editor-block metadata (manual guides and friends) for a slide.
final class SetSceneMetaCommand extends EditorCommand {
  /// Merges [meta] into slide [index]'s editor metadata. A non-null
  /// [mergeGroup] coalesces a stream (a guide drag) into one undo step.
  const SetSceneMetaCommand({required this.index, required this.meta, this.mergeGroup});

  /// The slide being annotated.
  final int index;

  /// The metadata to merge.
  final Map<String, Object?> meta;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.setSceneMeta(index, meta);

  @override
  String get label => 'Annotate slide';

  @override
  Set<String> get affectedIds => const {};

  @override
  String? get mergeKey =>
      mergeGroup == null ? null : 'sceneMeta:$mergeGroup:$index:${meta.keys.join(',')}';
}

/// Moves a run of slides — a section — as one unit.
final class ReorderSceneRangeCommand extends EditorCommand {
  /// Moves the [count] slides starting at [start] so the run begins at [to].
  const ReorderSceneRangeCommand({required this.start, required this.count, required this.to});

  /// The run's first slide.
  final int start;

  /// How many slides move together.
  final int count;

  /// Where the run starts after the move.
  final int to;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.reorderSceneRange(start: start, count: count, to: to);

  @override
  String get label => 'Move section';

  @override
  Set<String> get affectedIds => const {};
}

/// Moves a slide.
final class ReorderSceneCommand extends EditorCommand {
  /// Moves slide [from] to [to].
  const ReorderSceneCommand({required this.from, required this.to});

  /// The slide's current position.
  final int from;

  /// The slide's target position.
  final int to;

  @override
  EditorDocument apply(EditorDocument document) => document.reorderScene(from, to);

  @override
  String get label => 'Move slide';

  @override
  Set<String> get affectedIds => const {};
}
