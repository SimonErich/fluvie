import 'package:fluvie/src/animation/keyframed_number.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

final _maps = Expando<Map<(int, int), List<double>>>('clip speed integrals');

/// Cumulative source seconds at every output-frame boundary, including the
/// exclusive endpoint. All clip consumers use this map: frame planning,
/// preview, paint, streaming decode and embedded-audio tempo.
///
/// Integrates the authored curve with eight Simpson subintervals per output
/// frame. A linear ramp is exact; eased ramps share the same deterministic
/// sampled integral on every encoder. Positive speeds only; reversing remains
/// an explicit scalar operation with source audio omitted.
List<double> integrateClipSpeedRamp(
  KeyframedNumber ramp, {
  required int fps,
  required int windowFrames,
}) {
  final cache = _maps[ramp] ??= {};
  final key = (fps, windowFrames);
  if (cache[key] case final existing?) return existing;
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: windowFrames);
  final positions = [for (final position in ramp.positions) position.resolveFrames(scope)];
  if (ramp.values.length < 2 ||
      ramp.values.any((value) => !value.isFinite || value <= 0) ||
      positions.length != ramp.values.length ||
      ramp.easings.length != ramp.values.length - 1 ||
      positions.indexed.skip(1).any((entry) => entry.$2 <= positions[entry.$1 - 1])) {
    throw FluvieSpecError(
      'Speed ramp stops must be positive finite rates at strictly increasing times',
      path: const ['speed'],
    );
  }
  double rate(double frame) {
    final value = ramp.at((
      progress: windowFrames == 0 ? 0 : frame / windowFrames,
      fps: fps,
      windowFrames: windowFrames,
    ));
    if (!value.isFinite || value <= 0) {
      throw FluvieSpecError(
        'A speed ramp must never cross zero; use scalar Reverse for backwards playback',
        path: const ['speed'],
      );
    }
    return value;
  }

  const steps = 8;
  final result = <double>[0];
  for (var frame = 0; frame < windowFrames; frame++) {
    var sum = rate(frame.toDouble()) + rate(frame + 1.0);
    for (var i = 1; i < steps; i++) {
      sum += (i.isOdd ? 4 : 2) * rate(frame + i / steps);
    }
    result.add(result.last + sum / (3 * steps * fps));
  }
  if (cache.length >= 4) cache.remove(cache.keys.first);
  return cache[key] = List.unmodifiable(result);
}
