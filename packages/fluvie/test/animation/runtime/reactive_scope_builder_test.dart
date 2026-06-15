import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope_builder.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';

import '../../rendering/fakes/fake_media_resolver.dart';

BandTable _bass(double value) => BandTable({
  AudioBand.bass: Float64List.fromList([value]),
});

class _NoGrid implements BeatGrid {
  @override
  int? firstBeatAtOrAfter(int frame, {int every = 1}) => null;
}

// The FakeMediaResolver serves canned analysis, so these services are never
// invoked — they exist only to satisfy the required-parameter contract.
class _UnusedBeats implements BeatDetectionService {
  @override
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames}) =>
      throw UnimplementedError();
}

class _UnusedAnalyzer implements FrequencyAnalyzer {
  @override
  Future<BandTable> analyze(AudioSource source, {required int fps, required int totalFrames}) =>
      throw UnimplementedError();
}

void main() {
  group('reactiveScopeFor', () {
    test('returns the child unchanged when no default source is present', () {
      final scope = reactiveScopeFor(
        const ReactiveTracks(byAnchor: {}, defaultSource: null, allSources: {}),
        FakeMediaResolver(const {}),
        const SizedBox(),
      );
      expect(scope, isA<SizedBox>());
    });

    testWidgets('builds a ReactiveScope carrying the default and per-track tables', (
      tester,
    ) async {
      final beat = Anchor('beat');
      const master = AudioSource.asset('master.mp3');
      const tracked = AudioSource.asset('track.mp3');
      final resolver = FakeMediaResolver(
        const {},
        bandTables: {master: _bass(0.4), tracked: _bass(0.9)},
        beatGrids: {master: _NoGrid(), tracked: _NoGrid()},
      );
      await resolver.preResolveReactive(
        const [master, tracked],
        beatDetector: _UnusedBeats(),
        analyzer: _UnusedAnalyzer(),
        fps: 30,
        totalFrames: 1,
      );
      final tracks = ReactiveTracks(
        byAnchor: {beat: tracked},
        defaultSource: master,
        allSources: {master, tracked},
      );

      late BandTable? defaultTable;
      late BandTable? trackedTable;
      final scope = reactiveScopeFor(
        tracks,
        resolver,
        Builder(
          builder: (context) {
            defaultTable = ReactiveScope.tableFor(context, null);
            trackedTable = ReactiveScope.tableFor(context, beat);
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(scope);

      expect(defaultTable!.energyAt(0, AudioBand.bass), 0.4);
      expect(trackedTable!.energyAt(0, AudioBand.bass), 0.9);
    });
  });
}
