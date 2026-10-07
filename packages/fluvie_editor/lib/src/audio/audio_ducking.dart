import 'dart:math' as math;

import 'package:fluvie/fluvie.dart' show FrameSpan;

/// Computes plain linear automation from trigger presence. Adjacent/overlapping
/// events merge so hold/release never rise under another active trigger. All
/// times are relative to the target track; no special ducking object is saved.
Map<String, Object?> duckingAutomation({
  required List<FrameSpan> presence,
  required FrameSpan target,
  required int fps,
  double attenuationDb = -12,
  double attackSeconds = 0.1,
  double holdSeconds = 0.2,
  double releaseSeconds = 0.4,
}) {
  if (fps <= 0 ||
      !attenuationDb.isFinite ||
      attenuationDb > 0 ||
      [attackSeconds, holdSeconds, releaseSeconds].any((v) => !v.isFinite || v < 0)) {
    throw ArgumentError('Ducking needs finite non-negative times and attenuation at or below 0 dB');
  }
  final gain = math.pow(10, attenuationDb / 20).toDouble();
  final attack = (attackSeconds * fps).round();
  final hold = (holdSeconds * fps).round();
  final release = (releaseSeconds * fps).round();
  final events =
      presence
          .where(
            (span) => span.end + hold + release > target.start && span.start - attack < target.end,
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  if (events.isEmpty) return const {};
  final points = <int, double>{0: 1, target.durationFrames: 1};
  // Evaluate the minimum envelope at every change of slope; inserting pairwise
  // crossover points makes overlapping release/attack ramps exact too.
  final ramps = <List<(int, double)>>[
    for (final event in events)
      [
        (event.start - attack, 1),
        (event.start, gain),
        (event.end + hold, gain),
        (event.end + hold + release, 1),
      ],
  ];
  double at(List<(int, double)> ramp, int f) {
    if (f < ramp.first.$1 || f > ramp.last.$1) return 1;
    for (var i = 1; i < ramp.length; i++) {
      if (f <= ramp[i].$1) {
        final a = ramp[i - 1];
        final b = ramp[i];
        if (b.$1 == a.$1) return b.$2;
        return a.$2 + (b.$2 - a.$2) * (f - a.$1) / (b.$1 - a.$1);
      }
    }
    return 1;
  }

  // Frame sampling exactly matches the export clock and gives robust overlap
  // handling. Collinear samples are removed before serializing.
  final samples = <(int, double)>[];
  for (var frame = target.start; frame <= target.end; frame++) {
    var value = 1.0;
    for (final ramp in ramps) {
      value = math.min(value, at(ramp, frame));
    }
    samples.add((frame - target.start, value));
    while (samples.length >= 3) {
      final a = samples[samples.length - 3];
      final b = samples[samples.length - 2];
      final c = samples.last;
      final ab = (b.$2 - a.$2) / (b.$1 - a.$1);
      final bc = (c.$2 - b.$2) / (c.$1 - b.$1);
      if ((ab - bc).abs() > 1e-10) break;
      samples.removeAt(samples.length - 2);
    }
  }
  points.clear();
  for (final sample in samples) {
    points[sample.$1] = sample.$2;
  }
  if (points.length < 2) return {'volume': points.values.first};
  return {
    'volume': {
      'values': points.values.toList(),
      'positions': [for (final frame in points.keys) '${frame}f'],
    },
  };
}
