import 'package:flutter/foundation.dart' show immutable;
import 'package:fluvie_editor/src/document/editor_document.dart';

/// One intention against the document: applying it produces the next
/// document state, and its metadata drives the history (labels, selection
/// after undo, drag coalescing).
///
/// Commands are the only way the editor mutates a deck. They are sealed so
/// the history, the palette, and the tests can enumerate every intention.
@immutable
sealed class EditorCommand {
  const EditorCommand();

  /// The next document after this command.
  EditorDocument apply(EditorDocument document);

  /// What the undo menu calls this ("Move el-3").
  String get label;

  /// The element ids this command touches; undo re-selects them.
  Set<String> get affectedIds;

  /// Commands with the same non-null key coalesce into one undo step (a
  /// drag is a stream of [SetTransformCommand]s, undone as one).
  String? get mergeKey => null;
}

/// Moves or resizes an element: writes its `transform`.
final class SetTransformCommand extends EditorCommand {
  /// Sets [id]'s transform to [transform].
  const SetTransformCommand({required this.id, required this.transform});

  /// The element being placed.
  final String id;

  /// The new `transform` JSON (canvas fractions).
  final Map<String, Object?> transform;

  @override
  EditorDocument apply(EditorDocument document) => document.setTransform(id, transform);

  @override
  String get label => 'Move $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String get mergeKey => 'transform:$id';
}

/// Replaces an element's content wholesale (the inspector's big hammer).
final class ReplaceElementCommand extends EditorCommand {
  /// Replaces [id] with [element].
  const ReplaceElementCommand({required this.id, required this.element});

  /// The element being replaced.
  final String id;

  /// The new element JSON; the id is kept even when the patch omits it.
  final Map<String, Object?> element;

  @override
  EditorDocument apply(EditorDocument document) => document.replaceElement(id, element);

  @override
  String get label => 'Edit $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Adds an element to a scene. The caller mints [id] up front (through
/// `EditorDocument.nextId`), so undo and redo always see the same element.
final class InsertElementCommand extends EditorCommand {
  /// Inserts [element] into scene [scene] as [id] (appended, or at [at]).
  const InsertElementCommand({
    required this.scene,
    required this.element,
    required this.id,
    this.at,
  });

  /// The scene receiving the element.
  final int scene;

  /// The element JSON (its `id` key is overridden by [id]).
  final Map<String, Object?> element;

  /// The new element's identity.
  final String id;

  /// The z-position, or null to append.
  final int? at;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.insertElement(scene, {...element, 'id': id}, at: at).$1;

  @override
  String get label => 'Insert element';

  @override
  Set<String> get affectedIds => {id};
}

/// Deletes an element.
final class RemoveElementCommand extends EditorCommand {
  /// Removes [id].
  const RemoveElementCommand({required this.id});

  /// The element being removed.
  final String id;

  @override
  EditorDocument apply(EditorDocument document) => document.removeElement(id);

  @override
  String get label => 'Delete $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Changes an element's z-order within its scene.
final class ReorderElementCommand extends EditorCommand {
  /// Moves [id] to z-position [to].
  const ReorderElementCommand({required this.id, required this.to});

  /// The element being reordered.
  final String id;

  /// The target z-position.
  final int to;

  @override
  EditorDocument apply(EditorDocument document) => document.reorderElement(id, to: to);

  @override
  String get label => 'Reorder $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Writes editor-block metadata (name, lock, and friends) for an element.
final class SetElementMetaCommand extends EditorCommand {
  /// Merges [meta] into [id]'s editor metadata.
  const SetElementMetaCommand({required this.id, required this.meta});

  /// The element being annotated.
  final String id;

  /// The metadata to merge.
  final Map<String, Object?> meta;

  @override
  EditorDocument apply(EditorDocument document) => document.setElementMeta(id, meta);

  @override
  String get label => 'Annotate $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String get mergeKey => 'meta:$id:${meta.keys.join(',')}';
}

/// Adds a slide.
final class AddSceneCommand extends EditorCommand {
  /// Adds [scene] (appended, or at [at]).
  const AddSceneCommand({required this.scene, this.at});

  /// The scene JSON.
  final Map<String, Object?> scene;

  /// The slide position, or null to append.
  final int? at;

  @override
  EditorDocument apply(EditorDocument document) => document.addScene(scene, at: at);

  @override
  String get label => 'Add slide';

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
