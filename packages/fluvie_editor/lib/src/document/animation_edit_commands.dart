part of 'editor_command.dart';

/// Removes one animation from an element — the Animate panel's remove
/// action, and where deleting a keyframes bar below two stops lands.
final class RemoveAnimationCommand extends EditorCommand {
  /// Removes animation [index] of element [id].
  const RemoveAnimationCommand({required this.id, required this.index});

  /// The element losing the animation.
  final String id;

  /// Which `animate` entry goes.
  final int index;

  @override
  EditorDocument apply(EditorDocument document) => document.removeAnimation(id, index);

  @override
  String get label => 'Remove animation of $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Sets or clears one animation's easing (`ease` in the timing tail).
final class SetAnimationEaseCommand extends EditorCommand {
  /// Writes the named [ease] onto animation [index] of element [id];
  /// `null` clears the key back to the inherited cascade.
  const SetAnimationEaseCommand({required this.id, required this.index, required this.ease});

  /// The element whose animation eases.
  final String id;

  /// Which `animate` entry changes.
  final int index;

  /// A named ease or cubic control-point object, or null to inherit.
  final Object? ease;

  @override
  EditorDocument apply(EditorDocument document) {
    final animations = document.elementJson(id)!['animate']! as List;
    final current = animations[index]! as Map;
    final replacingSpring = ease != null && current['spring'] != null;
    final span = replacingSpring
        ? introspectTimeline(document.spec.build()).elementById(id)?.animations[index].span
        : null;
    return document.updateAnimation(id, index, {
      'ease': ease,
      if (replacingSpring) 'spring': null,
      if (span != null) 'duration': '${span.durationFrames}f',
    });
  }

  @override
  String get label => 'Ease animation of $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Sets or clears one animation's start trigger (`at` in the timing tail),
/// limited to the simple keyword forms the panel offers.
final class SetAnimationTriggerCommand extends EditorCommand {
  /// Writes the keyword [trigger] (`previous`, `sceneStart`, `sceneEnd`)
  /// onto animation [index] of element [id]; `null` clears the key back to
  /// the auto trigger.
  const SetAnimationTriggerCommand({required this.id, required this.index, required this.trigger});

  /// The element whose animation retriggers.
  final String id;

  /// Which `animate` entry changes.
  final int index;

  /// The keyword trigger form, or null for auto.
  final String? trigger;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.updateAnimation(id, index, {'at': trigger});

  @override
  String get label => 'Trigger animation of $id';

  @override
  Set<String> get affectedIds => {id};
}
