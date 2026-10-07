part of 'editor_command.dart';

/// Inserts one stop into a keyframes animation, splitting the segment it
/// lands in: the split segment's easing is duplicated so the curve around
/// the new stop keeps its authored shape, and the full `positions` list is
/// written in frames form.
final class InsertKeyframeStopCommand extends EditorCommand {
  /// Inserts [keyframe] as stop [stop] of animation [index] on element
  /// [id], with the stops sitting at [positionFrames] afterwards (one per
  /// stop, the inserted one included).
  const InsertKeyframeStopCommand({
    required this.id,
    required this.index,
    required this.stop,
    required this.keyframe,
    required this.positionFrames,
  });

  /// The element gaining the keyframe.
  final String id;

  /// Which `animate` entry gains the stop.
  final int index;

  /// Where the stop lands in the `keyframes` list.
  final int stop;

  /// The new stop's JSON (only the overridden fields, the codec form).
  final Map<String, Object?> keyframe;

  /// Every stop's position in bar-relative frames after the insert.
  final List<int> positionFrames;

  @override
  EditorDocument apply(EditorDocument document) {
    final animation = _animationJson(document, id, index);
    final stops = [...animation['keyframes']! as List]..insert(stop, {...keyframe});
    final existing = animation['easings'];
    return document.updateAnimation(id, index, {
      'keyframes': stops,
      if (existing is List && existing.isNotEmpty)
        'easings': [...existing]
          ..insert(
            stop.clamp(0, existing.length),
            existing[(stop - 1).clamp(0, existing.length - 1)],
          ),
      'positions': _framesJson(positionFrames),
    });
  }

  @override
  String get label => 'Add keyframe to $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Removes one stop from a keyframes animation, together with its easing
/// segment and its authored position.
///
/// A middle or first stop takes its outgoing segment's easing with it; the
/// last stop drops its incoming segment instead (there is no outgoing one).
/// Deleting below two stops is the caller's problem — the panel removes the
/// whole animation instead, because a one-stop keyframes form is invalid.
final class RemoveKeyframeStopCommand extends EditorCommand {
  /// Removes stop [stop] of animation [index] on element [id].
  const RemoveKeyframeStopCommand({required this.id, required this.index, required this.stop});

  /// The element losing the keyframe.
  final String id;

  /// Which `animate` entry loses the stop.
  final int index;

  /// The stop's index in the `keyframes` list.
  final int stop;

  @override
  EditorDocument apply(EditorDocument document) {
    final animation = _animationJson(document, id, index);
    final stops = [...animation['keyframes']! as List];
    RangeError.checkValidIndex(stop, stops, 'stop');
    final segment = stop == stops.length - 1 ? stop - 1 : stop;
    stops.removeAt(stop);
    final easings = animation['easings'];
    final positions = animation['positions'];
    return document.updateAnimation(id, index, {
      'keyframes': stops,
      if (easings is List && segment < easings.length) 'easings': [...easings]..removeAt(segment),
      if (positions is List && stop < positions.length) 'positions': [...positions]..removeAt(stop),
    });
  }

  @override
  String get label => 'Remove keyframe of $id';

  @override
  Set<String> get affectedIds => {id};
}
