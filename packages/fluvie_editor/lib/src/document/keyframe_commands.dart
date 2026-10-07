part of 'editor_command.dart';

/// The frames form of a positions list — the honest unit every keyframe
/// edit writes, whatever unit the author typed.
List<String> _framesJson(List<int> frames) => [for (final frame in frames) '${frame}f'];

/// The current JSON of animation [index] on element [id] — what the splice
/// commands read before writing the changed lists back.
Map<String, Object?> _animationJson(EditorDocument document, String id, int index) {
  final element = document.elementJson(id);
  if (element == null) {
    throw ArgumentError.value(id, 'id', 'No element with this id');
  }
  final animate = element['animate'];
  final list = animate is List ? animate : const <Object?>[];
  RangeError.checkValidIndex(index, list, 'index');
  return (list[index]! as Map).cast<String, Object?>();
}

/// Repositions the stops of one keyframes animation: writes the full
/// `positions` list in frames form. When the form had none (evenly spaced
/// stops), the first move mints the whole list — the honest write.
final class SetKeyframePositionsCommand extends EditorCommand {
  /// Sets the stops of animation [index] on element [id] to
  /// [positionFrames] (bar-relative frames, one per stop). A non-null
  /// [mergeGroup] coalesces a drag's stream of moves into one undo step.
  const SetKeyframePositionsCommand({
    required this.id,
    required this.index,
    required this.positionFrames,
    this.mergeGroup,
  });

  /// The element whose keyframes move.
  final String id;

  /// Which `animate` entry holds the stops.
  final int index;

  /// The new stop positions in bar-relative frames, one per stop.
  final List<int> positionFrames;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.updateAnimation(id, index, {'positions': _framesJson(positionFrames)});

  @override
  String get label => 'Move keyframe of $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'kf-pos:$mergeGroup:$id:$index';
}

/// Replaces the values of one keyframe stop (the inspector's field edits).
final class SetKeyframeStopCommand extends EditorCommand {
  /// Sets stop [stop] of animation [index] on element [id] to [keyframe].
  /// A non-null [mergeGroup] coalesces a run of edits (arrow-stepping one
  /// field) into one undo step.
  const SetKeyframeStopCommand({
    required this.id,
    required this.index,
    required this.stop,
    required this.keyframe,
    this.mergeGroup,
  });

  /// The element whose keyframe changes.
  final String id;

  /// Which `animate` entry holds the stop.
  final int index;

  /// The stop's index in the `keyframes` list.
  final int stop;

  /// The stop's new JSON (only the overridden fields, the codec form).
  final Map<String, Object?> keyframe;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) {
    final stops = [..._animationJson(document, id, index)['keyframes']! as List];
    RangeError.checkValidIndex(stop, stops, 'stop');
    stops[stop] = {...keyframe};
    return document.updateAnimation(id, index, {'keyframes': stops});
  }

  @override
  String get label => 'Edit keyframe of $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'kf-stop:$mergeGroup:$id:$index:$stop';
}

/// Sets the easing of one segment between two keyframe stops.
final class SetKeyframeEasingCommand extends EditorCommand {
  /// Sets segment [segment] (from stop `segment` to stop `segment + 1`) of
  /// animation [index] on element [id] to the named [easing].
  const SetKeyframeEasingCommand({
    required this.id,
    required this.index,
    required this.segment,
    required this.easing,
  });

  /// The element whose segment easing changes.
  final String id;

  /// Which `animate` entry holds the segment.
  final int index;

  /// The segment's index (`easings[segment]` shapes stop `segment` to
  /// `segment + 1`).
  final int segment;

  /// The named ease to write (a `namedEases` key).
  final Object easing;

  @override
  EditorDocument apply(EditorDocument document) {
    final animation = _animationJson(document, id, index);
    final stops = animation['keyframes']! as List;
    final existing = animation['easings'];
    final easings = existing is List
        ? [...existing]
        : List<Object?>.filled(stops.length - 1, 'linear');
    RangeError.checkValidIndex(segment, easings, 'segment');
    easings[segment] = easing;
    return document.updateAnimation(id, index, {'easings': easings});
  }

  @override
  String get label => 'Ease keyframe segment of $id';

  @override
  Set<String> get affectedIds => {id};
}
