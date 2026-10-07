part of 'editor_command.dart';

/// The frames form of a delay tail value: `null` clears the key at zero
/// (no delay and a zero delay are the same statement).
String? _delayJson(int frames) => frames <= 0 ? null : '${frames}f';

/// Retimes one animation: writes its `delay` in frames form — the honest
/// unit for a timeline drag. Deltas stay relative to the animation's own
/// trigger, so retiming works the same for auto, `previous`, and
/// cross-element triggers.
final class SetAnimationDelayCommand extends EditorCommand {
  /// Sets animation [index] of element [id] to start [delayFrames] frames
  /// after its trigger. A non-null [mergeGroup] coalesces a drag's stream
  /// of retimes into one undo step.
  const SetAnimationDelayCommand({
    required this.id,
    required this.index,
    required this.delayFrames,
    this.mergeGroup,
  });

  /// The element whose animation moves.
  final String id;

  /// Which `animate` entry moves.
  final int index;

  /// The new delay after the trigger, in scene-relative frames.
  final int delayFrames;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.updateAnimation(id, index, {'delay': _delayJson(delayFrames)});

  @override
  String get label => 'Retime $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'anim-delay:$mergeGroup:$id:$index';
}

/// Trims one animation: writes its `duration` (and, for a left-edge trim
/// that moves the start too, its `delay`) in frames form.
final class SetAnimationDurationCommand extends EditorCommand {
  /// Sets animation [index] of element [id] to run [durationFrames] frames;
  /// a non-null [delayFrames] moves its start in the same step (the
  /// left-edge trim), and a non-null [positionFrames] rewrites a keyframes
  /// form's authored stop positions in the same step (the rescale that
  /// keeps stops proportional through a trim). A non-null [mergeGroup]
  /// coalesces a drag's stream of trims into one undo step.
  const SetAnimationDurationCommand({
    required this.id,
    required this.index,
    required this.durationFrames,
    this.delayFrames,
    this.positionFrames,
    this.mergeGroup,
  });

  /// The element whose animation is trimmed.
  final String id;

  /// Which `animate` entry is trimmed.
  final int index;

  /// The new duration in frames.
  final int durationFrames;

  /// The new delay in scene-relative frames, or null to leave the start.
  final int? delayFrames;

  /// The rescaled stop positions in bar-relative frames, or null to leave
  /// the `positions` key.
  final List<int>? positionFrames;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.updateAnimation(id, index, {
    'duration': '${durationFrames}f',
    if (delayFrames != null) 'delay': _delayJson(delayFrames!),
    if (positionFrames != null) 'positions': _framesJson(positionFrames!),
  });

  @override
  String get label => 'Trim $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'anim-duration:$mergeGroup:$id:$index';
}

/// Adds an animation to an element — the empty timeline's way out.
final class AddAnimationCommand extends EditorCommand {
  /// Appends [animation] to element [id]'s `animate` list.
  const AddAnimationCommand({required this.id, required this.animation});

  /// The element gaining the animation.
  final String id;

  /// The animation JSON to append.
  final Map<String, Object?> animation;

  @override
  EditorDocument apply(EditorDocument document) => document.addAnimation(id, animation);

  @override
  String get label => 'Animate $id';

  @override
  Set<String> get affectedIds => {id};
}
