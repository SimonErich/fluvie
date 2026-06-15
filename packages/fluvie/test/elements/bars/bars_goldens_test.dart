// WI-14 (§18): the Bars reactive golden. Bars are frame-driven by a precomputed
// BandTable, so the golden mounts a fixture table under a ReactiveScope and
// snapshots the bars at one representative frame (the loud-bass peak). The fill
// color comes from the fallback tokens, so the golden is font-free and stable.
@Tags(['golden'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/elements/bars/bars.dart';

import '../../animation/helpers/golden_frame.dart';

/// A fixture band table that ramps bass to its peak at frame 30 (the probed
/// golden frame), so the bars stand near full height.
BandTable _fixtureTable() {
  final bass = Float64List(60);
  for (var f = 0; f < 60; f++) {
    bass[f] = f / 59;
  }
  return BandTable({
    AudioBand.bass: bass,
    AudioBand.mid: Float64List(60),
    AudioBand.treble: Float64List(60),
  });
}

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Bars: a 24-bar bass spectrum near its peak',
    fileName: 'bars_bass_peak',
    frames: const [30],
    subject: () => ReactiveScope(
      table: _fixtureTable(),
      child: const Bars(count: 20, gain: 0.9),
    ),
  );
}
