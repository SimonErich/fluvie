part of 'editor_command.dart';

/// Rewrites a slide's build steps (`steps` on the scene) — where every
/// marker gesture on the timeline ruler lands.
final class SetSceneStepsCommand extends EditorCommand {
  /// Writes [steps] onto slide [index]; `null` (or an empty list) removes
  /// the key — a step-less slide is one base step. A non-null [mergeGroup]
  /// coalesces a marker drag's stream of rewrites into one undo step.
  const SetSceneStepsCommand({required this.index, required this.steps, this.mergeGroup});

  /// The slide whose steps change.
  final int index;

  /// The new `steps` list, or null to remove it.
  final List<Object?>? steps;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.updateScene(index, {
    'steps': (steps == null || steps!.isEmpty) ? null : steps,
  });

  @override
  String get label => 'Edit build steps';

  @override
  Set<String> get affectedIds => const {};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'scene-steps:$mergeGroup:$index';
}

/// Points one animation's start trigger at another element: writes the
/// object form `{kind, anchor}` and declares the anchor on the target in
/// the same undo step — how a dropped trigger link lands.
final class SetAnimationAnchorTriggerCommand extends EditorCommand {
  /// Sets animation [index] of element [id] to start off [targetId]'s
  /// anchor: [kind] is `whenEnds` or `whenStarts`, and [anchorId] is the
  /// anchor to reference — the target's existing anchor id, or a fresh one
  /// minted by the caller (commands carry their ids).
  const SetAnimationAnchorTriggerCommand({
    required this.id,
    required this.index,
    required this.kind,
    required this.targetId,
    required this.anchorId,
  });

  /// The element whose animation retriggers.
  final String id;

  /// Which `animate` entry changes.
  final int index;

  /// The trigger kind: `whenEnds` or `whenStarts`.
  final String kind;

  /// The element whose anchor the trigger references.
  final String targetId;

  /// The anchor id to declare (when absent) and reference.
  final String anchorId;

  @override
  EditorDocument apply(EditorDocument document) {
    var next = document;
    final target = next.elementJson(targetId)!;
    if (target['anchor'] != anchorId) {
      next = next.replaceElement(targetId, {...target, 'anchor': anchorId});
    }
    return next.updateAnimation(id, index, {
      'at': {'kind': kind, 'anchor': anchorId},
    });
  }

  @override
  String get label => 'Trigger $id off $targetId';

  @override
  Set<String> get affectedIds => {id, targetId};
}
