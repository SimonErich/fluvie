part of 'editor_command.dart';

/// The current JSON of the keyframed parameter [param] of effect [index] on
/// element [id] — what every stop edit reads before writing back.
Map<String, Object?> _effectParamJson(EditorDocument document, String id, int index, String param) {
  final element = document.elementJson(id);
  if (element == null) {
    throw ArgumentError.value(id, 'id', 'No element with this id');
  }
  final effects = element['effects'];
  final list = effects is List ? effects : const <Object?>[];
  RangeError.checkValidIndex(index, list, 'index');
  final effect = (list[index]! as Map).cast<String, Object?>();
  return (effect[param]! as Map).cast<String, Object?>();
}

/// Inserts one stop into a keyframed effect parameter, splitting the segment
/// it lands in: the split segment's easing is duplicated so the curve around
/// the new stop keeps its authored shape, and the full `positions` list is
/// written in frames form.
final class InsertEffectStopCommand extends EditorCommand {
  /// Inserts [value] as stop [stop] of parameter [param] on effect [index]
  /// of element [id], with the stops sitting at [positionFrames] afterwards
  /// (one per stop, the inserted one included).
  const InsertEffectStopCommand({
    required this.id,
    required this.index,
    required this.param,
    required this.stop,
    required this.value,
    required this.positionFrames,
  });

  /// The element whose effect gains the stop.
  final String id;

  /// Which `effects` entry holds the parameter.
  final int index;

  /// The keyframed parameter's name.
  final String param;

  /// Where the stop lands in the `values` list.
  final int stop;

  /// The new stop's value — the number the ramp already reads there.
  final double value;

  /// Every stop's position in bar-relative frames after the insert.
  final List<int> positionFrames;

  @override
  EditorDocument apply(EditorDocument document) {
    final current = _effectParamJson(document, id, index, param);
    final values = [...current['values']! as List]..insert(stop, value);
    final easings = current['easings'];
    return document.updateEffect(id, index, {
      param: {
        'values': values,
        'positions': _framesJson(positionFrames),
        if (easings is List && easings.isNotEmpty)
          'easings': [...easings]
            ..insert(
              stop.clamp(0, easings.length),
              easings[(stop - 1).clamp(0, easings.length - 1)],
            ),
      },
    });
  }

  @override
  String get label => 'Add effect keyframe to $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Repositions the stops of one keyframed effect parameter: writes the full
/// `positions` list in frames form and touches nothing else.
final class SetEffectStopPositionsCommand extends EditorCommand {
  /// Sets the stops of parameter [param] on effect [index] of element [id]
  /// to [positionFrames] (bar-relative frames, one per stop). A non-null
  /// [mergeGroup] coalesces a drag's stream of moves into one undo step.
  const SetEffectStopPositionsCommand({
    required this.id,
    required this.index,
    required this.param,
    required this.positionFrames,
    this.mergeGroup,
  });

  /// The element whose effect keyframes move.
  final String id;

  /// Which `effects` entry holds the parameter.
  final int index;

  /// The keyframed parameter's name.
  final String param;

  /// The new stop positions in bar-relative frames, one per stop.
  final List<int> positionFrames;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) {
    final current = _effectParamJson(document, id, index, param);
    return document.updateEffect(id, index, {
      param: {...current, 'positions': _framesJson(positionFrames)},
    });
  }

  @override
  String get label => 'Move effect keyframe of $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'fx-pos:$mergeGroup:$id:$index:$param';
}

/// Removes one stop from a keyframed effect parameter, together with its
/// easing segment and its position.
///
/// A middle or first stop takes its outgoing segment's easing with it; the
/// last stop drops its incoming segment instead. At the two-stop minimum the
/// parameter collapses to a literal — the surviving stop's value — because a
/// one-stop keyframed value is a plain number wearing a list.
final class RemoveEffectStopCommand extends EditorCommand {
  /// Removes stop [stop] of parameter [param] on effect [index] of element
  /// [id].
  const RemoveEffectStopCommand({
    required this.id,
    required this.index,
    required this.param,
    required this.stop,
  });

  /// The element whose effect loses the stop.
  final String id;

  /// Which `effects` entry holds the parameter.
  final int index;

  /// The keyframed parameter's name.
  final String param;

  /// The stop's index in the `values` list.
  final int stop;

  @override
  EditorDocument apply(EditorDocument document) {
    final current = _effectParamJson(document, id, index, param);
    final values = [...current['values']! as List];
    RangeError.checkValidIndex(stop, values, 'stop');
    if (values.length <= 2) {
      return document.updateEffect(id, index, {param: values[1 - stop]});
    }
    final segment = stop == values.length - 1 ? stop - 1 : stop;
    values.removeAt(stop);
    final easings = current['easings'];
    final positions = current['positions'];
    return document.updateEffect(id, index, {
      param: {
        'values': values,
        if (positions is List && stop < positions.length)
          'positions': [...positions]..removeAt(stop),
        if (easings is List && segment < easings.length) 'easings': [...easings]..removeAt(segment),
      },
    });
  }

  @override
  String get label => 'Remove effect keyframe of $id';

  @override
  Set<String> get affectedIds => {id};
}
