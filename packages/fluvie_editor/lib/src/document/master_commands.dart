part of 'editor_command.dart';

/// Writes one master of the deck's `masters` block wholesale — every
/// master-edit-mode change lands as one of these, so a master edit is one
/// undoable step that re-derives every adopting slide.
final class SetMasterCommand extends EditorCommand {
  /// Sets the master [name] to [master] (null removes it). A non-null
  /// [mergeGroup] coalesces a stream (a gizmo drag inside master-edit mode)
  /// into one step; [verb] names the step for the undo menu.
  const SetMasterCommand({
    required this.name,
    required this.master,
    this.mergeGroup,
    this.verb = 'Edit',
  });

  /// The master being written.
  final String name;

  /// The whole new master JSON, or null to remove it.
  final Map<String, Object?>? master;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  /// What the undo menu calls this ("Edit", "Add").
  final String verb;

  @override
  EditorDocument apply(EditorDocument document) => document.setMasterJson(name, master);

  @override
  String get label => '$verb master';

  @override
  Set<String> get affectedIds => const {};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'master:$mergeGroup:$name';
}

/// Adopts a master on one slide. Fills whose slots the new master defines
/// stay fills; orphans promote to plain scene children with their resolved
/// look, so switching masters never loses content.
final class ApplyMasterCommand extends EditorCommand {
  /// Adopts the master [name] on slide [slide].
  const ApplyMasterCommand({required this.slide, required this.name});

  /// The slide adopting the master.
  final int slide;

  /// The master being adopted.
  final String name;

  @override
  EditorDocument apply(EditorDocument document) => document.applyMaster(slide, name);

  @override
  String get label => 'Apply master';

  @override
  Set<String> get affectedIds => const {};
}

/// Releases a slide from its master. Every fill promotes to a plain scene
/// child with its resolved look; the master's chrome stays with the master.
final class DetachMasterCommand extends EditorCommand {
  /// Detaches slide [slide] from its master.
  const DetachMasterCommand({required this.slide});

  /// The slide being released.
  final int slide;

  @override
  EditorDocument apply(EditorDocument document) => document.detachMaster(slide);

  @override
  String get label => 'Detach master';

  @override
  Set<String> get affectedIds => const {};
}

/// Fills one slot of an adopting slide's master. The caller mints [id] up
/// front (through `EditorDocument.nextId`), so undo and redo always see the
/// same fill element.
final class FillSlotCommand extends EditorCommand {
  /// Writes [element] as slide [slide]'s fill for [slot], identified by [id].
  const FillSlotCommand({
    required this.slide,
    required this.slot,
    required this.id,
    required this.element,
  });

  /// The slide whose slot is filled.
  final int slide;

  /// The slot being filled.
  final String slot;

  /// The fill's identity (overrides any `id` inside [element]).
  final String id;

  /// The fill element JSON.
  final Map<String, Object?> element;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.fillSlot(slide, slot, {...element, 'id': id});

  @override
  String get label => 'Fill $slot';

  @override
  Set<String> get affectedIds => {id};
}
