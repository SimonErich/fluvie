import 'dart:math' as math;

import 'package:fluvie/src/audio/encoding/audio_filter_graph.dart';
import 'package:fluvie/src/core/audio/audio_time_map.dart';

/// Compiles an integrated clip clock to persistent, pitch-preserving tempo
/// stages. Commands use the pre-tempo source clock, and packetization limits
/// command timing error to 128 input samples. All text is generated numbers.
List<String> audioTimeMapFilters(AudioTimeMap map, int inputIndex) {
  map.validate();
  final rates = [
    for (var i = 0; i < map.sourceSeconds.length - 1; i++)
      (map.sourceSeconds[i + 1] - map.sourceSeconds[i]) * map.fps,
  ];
  var stages = 1;
  for (final rate in rates) {
    stages = math.max(stages, (math.log(rate).abs() / math.ln2).ceil());
  }
  final names = [for (var stage = 0; stage < stages; stage++) 'atempo@ramp_${inputIndex}_$stage'];
  double factor(double rate) => math.pow(rate, 1 / stages).toDouble().clamp(0.5, 2.0);
  final commands = <String>[];
  for (var i = 1; i < rates.length; i++) {
    if ((rates[i] - rates[i - 1]).abs() < 1e-10) continue;
    commands.add(
      '${formatFilterNumber(map.sourceSeconds[i])} ${[
        for (final name in names) '$name tempo ${formatFilterNumber(factor(rates[i]))}',
      ].join(',')}',
    );
  }
  return [
    if (commands.isNotEmpty) 'asetnsamples=n=128:p=0',
    if (commands.isNotEmpty) "asendcmd=c='${commands.join(';')}'",
    for (final name in names) '$name=${formatFilterNumber(factor(rates.first))}',
    'apad',
    'atrim=duration=${formatFilterNumber(map.durationSeconds)}',
  ];
}
