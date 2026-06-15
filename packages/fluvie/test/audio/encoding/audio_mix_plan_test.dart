import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_plan.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';

void main() {
  group('buildAudioMixPlan', () {
    test('no tracks yields an empty plan (no nodes, no amix)', () {
      final plan = buildAudioMixPlan(const []);
      expect(plan.tracks, isEmpty);
      expect(plan.amix, isNull);
    });

    test('one track yields one node and an amix of one input', () {
      final plan = buildAudioMixPlan(const [AudioTrackNode(name: 'song.wav')]);
      expect(plan.tracks, hasLength(1));
      expect(plan.tracks.single.name, 'song.wav');
      expect(plan.amix, isNotNull);
      expect(plan.amix!.inputCount, 1);
    });

    test('the master volume is carried onto the amix', () {
      final plan = buildAudioMixPlan(
        const [AudioTrackNode(name: 'song.wav')],
        masterVolume: 0.7,
      );
      expect(plan.amix!.masterVolume, 0.7);
    });

    test('multiple tracks produce an amix matching the track count', () {
      final plan = buildAudioMixPlan(const [
        AudioTrackNode(name: 'a.wav'),
        AudioTrackNode(name: 'b.wav', delayMs: 500),
      ]);
      expect(plan.tracks, hasLength(2));
      expect(plan.amix!.inputCount, 2);
    });

    test('the plan is order-stable across builds (determinism)', () {
      List<String> argsFor() {
        final plan = buildAudioMixPlan(const [
          AudioTrackNode(name: 'a.wav'),
          AudioTrackNode(name: 'b.wav', delayMs: 500),
        ]);
        return [
          for (final track in plan.tracks) track.filterChain(inputIndex: 1, label: 'a0'),
        ];
      }

      expect(argsFor(), argsFor());
    });
  });
}
