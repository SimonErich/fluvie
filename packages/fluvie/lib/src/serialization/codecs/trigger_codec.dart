import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';

/// The JSON form of a [Trigger].
///
/// The keyword triggers are bare strings (`"auto"`, `"sceneStart"`,
/// `"sceneEnd"`, `"previous"`); the rest are objects tagged by `kind`
/// (`at`, `beat`, `after`, `whenStarts`). Anchor references serialize as the
/// anchor's id (its `debugName`); a referenced anchor with no id throws a
/// [FluvieSpecError] (located at [path]).
Object encodeTrigger(Trigger trigger, {List<String> path = const []}) => switch (trigger) {
  AutoTrigger() => 'auto',
  SceneStartTrigger() => 'sceneStart',
  SceneEndTrigger() => 'sceneEnd',
  PreviousTrigger() => 'previous',
  AbsoluteTrigger(:final time) => {'kind': 'at', 'time': encodeTime(time, path: path)},
  BeatTrigger(:final every, :final track) => {
    'kind': 'beat',
    'every': every,
    if (track != null) 'track': _anchorId(track, path),
  },
  AfterTrigger(:final anchor) => {'kind': 'after', 'anchor': _anchorId(anchor, path)},
  WhenStartsTrigger(:final anchor) => {'kind': 'whenStarts', 'anchor': _anchorId(anchor, path)},
};

/// Reads a [Trigger] from [raw], resolving anchor ids through [anchors].
///
/// Throws a [FluvieSpecError] (located at [path]) for an unknown name/kind or a
/// missing anchor reference.
Trigger decodeTrigger(Object? raw, AnchorTable anchors, {List<String> path = const []}) {
  if (raw is String) {
    return switch (raw) {
      'auto' => Trigger.auto,
      'sceneStart' => Trigger.sceneStart,
      'sceneEnd' => Trigger.sceneEnd,
      'previous' => Trigger.previous,
      _ => throw FluvieSpecError('Unknown trigger "$raw"', path: path),
    };
  }
  if (raw is Map<String, Object?>) {
    final kind = raw['kind'];
    switch (kind) {
      case 'at':
        return Trigger.at(decodeTime(raw['time'], path: [...path, 'time']));
      case 'beat':
        final every = raw['every'];
        final track = raw['track'];
        return Trigger.beat(
          every: every is int ? every : 1,
          track: track is String ? anchors.resolve(track) : null,
        );
      case 'after':
        return Trigger.after(anchors.resolve(_requireId(raw['anchor'], path)));
      case 'whenStarts':
        return Trigger.whenStarts(anchors.resolve(_requireId(raw['anchor'], path)));
    }
    throw FluvieSpecError('Unknown trigger kind "$kind"', path: path);
  }
  throw FluvieSpecError('Expected a trigger name or object', path: path);
}

String _anchorId(Anchor anchor, List<String> path) {
  final id = anchor.debugName;
  if (id == null) {
    throw FluvieSpecError(
      'An anchor referenced by a trigger has no id (debugName) to serialize',
      path: path,
    );
  }
  return id;
}

String _requireId(Object? raw, List<String> path) {
  if (raw is String) return raw;
  throw FluvieSpecError('Expected an anchor id (a string)', path: path);
}
