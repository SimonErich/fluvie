import 'package:fluvie/fluvie.dart'
    show Keyframe, KeyframedNumber, TimeScope, decodeKeyframe, decodeTime, encodeKeyframe;

/// Pure math for keyframe stops on a timeline bar: where the stops of a
/// `keyframes` animation sit in frames, and what a move, an insert, or a
/// retime does to them. Everything works in bar-relative whole frames — the
/// scene-relative unit every command writes.

/// The resolved bar-relative frame of every stop of [animation] (a
/// `keyframes`-form animation JSON) across a span of [spanFrames], or `null`
/// when the animation is not the keyframes form.
///
/// An authored `positions` list resolves each `Time` against the span
/// (mirroring how the animation pipeline resolves stop fractions); without
/// one the stops space evenly, the documented default.
List<int>? keyframeStopFrames(
  Map<String, Object?> animation, {
  required int spanFrames,
  required int fps,
}) {
  final stops = animation['keyframes'];
  if (stops is! List || stops.length < 2) return null;
  final positions = animation['positions'];
  if (positions is List && positions.length == stops.length) {
    final scope = _SpanScope(fps, spanFrames);
    return [for (final position in positions) decodeTime(position).resolveFrames(scope)];
  }
  return [for (var i = 0; i < stops.length; i++) (i * spanFrames / (stops.length - 1)).round()];
}

/// [stopFrames] with stop [stop] moved to [offset], clamped strictly
/// between its neighbors (boundary stops clamp to `0..span`), or `null`
/// when the move changes nothing or the neighbors leave no room.
List<int>? movedStopFrames({
  required List<int> stopFrames,
  required int stop,
  required int offset,
  required int span,
}) {
  final lower = stop == 0 ? 0 : stopFrames[stop - 1] + 1;
  final upper = stop == stopFrames.length - 1 ? span : stopFrames[stop + 1] - 1;
  if (lower > upper) return null;
  final moved = offset.clamp(lower, upper);
  if (moved == stopFrames[stop]) return null;
  return [...stopFrames]..[stop] = moved;
}

/// The stop inserted at [offset] between the [stops] sitting at
/// [stopFrames]: its index, its values interpolated from the neighboring
/// stops (a boundary insert copies the boundary stop), and the full new
/// positions list. `null` when [offset] already holds a stop.
///
/// Interpolation follows [Keyframe.lerp]: fields only one neighbor defines
/// substitute that field's natural identity on the silent side, and fields
/// neither defines stay absent — the inserted stop changes nothing visually.
({int stop, Map<String, Object?> keyframe, List<int> positionFrames})? insertedStop({
  required List<Object?> stops,
  required List<int> stopFrames,
  required int offset,
}) {
  if (stopFrames.contains(offset)) return null;
  var index = stopFrames.length;
  for (var i = 0; i < stopFrames.length; i++) {
    if (offset < stopFrames[i]) {
      index = i;
      break;
    }
  }
  final Map<String, Object?> keyframe;
  if (index == 0) {
    keyframe = _stopJson(stops.first);
  } else if (index == stops.length) {
    keyframe = _stopJson(stops.last);
  } else {
    final left = stopFrames[index - 1];
    final right = stopFrames[index];
    keyframe = encodeKeyframe(
      Keyframe.lerp(
        decodeKeyframe(_stopJson(stops[index - 1])),
        decodeKeyframe(_stopJson(stops[index])),
        (offset - left) / (right - left),
      ),
    );
  }
  return (
    stop: index,
    keyframe: keyframe,
    positionFrames: [...stopFrames]..insert(index, offset),
  );
}

/// [stopFrames] rescaled proportionally from a span of [from] frames onto
/// [to] frames, nudged where rounding collides so the list stays strictly
/// increasing, or `null` when [to] cannot hold that many distinct frames.
List<int>? rescaledStopFrames(List<int> stopFrames, {required int from, required int to}) {
  if (to < stopFrames.length - 1) return null;
  final scaled = [for (final frame in stopFrames) (frame * to / from).round()];
  for (var i = 1; i < scaled.length; i++) {
    if (scaled[i] <= scaled[i - 1]) scaled[i] = scaled[i - 1] + 1;
  }
  if (scaled.last > to) {
    scaled[scaled.length - 1] = to;
    for (var i = scaled.length - 2; i >= 0; i--) {
      if (scaled[i] >= scaled[i + 1]) scaled[i] = scaled[i + 1] - 1;
    }
    if (scaled.first < 0) return null;
  }
  return scaled;
}

/// The resolved bar-relative frame of every stop of a keyframed effect
/// parameter [value] across a span of [spanFrames], or `null` when [value]
/// is not the keyframed shape (a plain number has no stops to place).
List<int>? keyframedValueStopFrames(Object? value, {required int spanFrames, required int fps}) {
  if (value is! Map<String, Object?>) return null;
  final positions = value['positions'];
  if (positions is! List) return null;
  final scope = _SpanScope(fps, spanFrames);
  return [for (final position in positions) decodeTime(position).resolveFrames(scope)];
}

/// The stop inserted at [offset] into the keyframed effect parameter
/// [param]: its index, the value the ramp already reads at that frame (so
/// the diamond changes nothing visually), and the full new positions list.
/// `null` when [offset] already holds a stop or [param] is not keyframed.
({int stop, double value, List<int> positionFrames})? insertedEffectStop({
  required Map<String, Object?> param,
  required List<int> stopFrames,
  required int offset,
  required int spanFrames,
  required int fps,
}) {
  if (stopFrames.contains(offset)) return null;
  final ramp = KeyframedNumber.maybeFromJson(param);
  if (ramp == null) return null;
  var index = stopFrames.length;
  for (var i = 0; i < stopFrames.length; i++) {
    if (offset < stopFrames[i]) {
      index = i;
      break;
    }
  }
  final progress = spanFrames <= 0 ? 0.0 : offset / spanFrames;
  return (
    stop: index,
    value: ramp.at((progress: progress, fps: fps, windowFrames: spanFrames)),
    positionFrames: [...stopFrames]..insert(index, offset),
  );
}

Map<String, Object?> _stopJson(Object? raw) =>
    raw is Map ? {...raw.cast<String, Object?>()} : const {};

/// Resolves a stop position `Time` against the bar's own span — what a
/// relative or seconds position means inside a keyframes animation.
final class _SpanScope implements TimeScope {
  const _SpanScope(this.fps, this.durationFrames);

  @override
  final int fps;

  @override
  final int durationFrames;

  @override
  int get startFrame => 0; // coverage:ignore-line TimeScope obligation never read by span resolution

  @override
  TimeScope? get parent => null; // coverage:ignore-line TimeScope obligation resolution uses the nearest scope only
}
