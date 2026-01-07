import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/audio/audio_data_provider.dart';

void main() {
  group('MockAudioDataProvider', () {
    group('construction', () {
      test('creates with default parameters', () {
        final provider = MockAudioDataProvider();

        expect(provider.bpm, 120);
        expect(provider.duration, 60);
        expect(provider.seed, 42);
        expect(provider.amplitudeVariation, 0.3);
      });

      test('creates with custom parameters', () {
        final provider = MockAudioDataProvider(
          bpm: 90,
          duration: 30,
          seed: 123,
          amplitudeVariation: 0.5,
        );

        expect(provider.bpm, 90);
        expect(provider.duration, 30);
        expect(provider.seed, 123);
        expect(provider.amplitudeVariation, 0.5);
      });
    });

    group('initialize', () {
      test('completes without error', () async {
        final provider = MockAudioDataProvider();

        await expectLater(provider.initialize(), completes);
      });

      test('initializes data for use', () async {
        final provider = MockAudioDataProvider();

        await provider.initialize();

        // After initialization, data should be available
        expect(provider.getBpm(), 120);
        expect(provider.getAmplitudeAt(0), greaterThanOrEqualTo(0.0));
      });
    });

    group('dispose', () {
      test('can be called without error', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        expect(() => provider.dispose(), returnsNormally);
      });
    });

    group('getBpm', () {
      test('returns configured BPM', () async {
        final provider = MockAudioDataProvider(bpm: 140);
        await provider.initialize();

        expect(provider.getBpm(), 140);
      });
    });

    group('getDuration', () {
      test('returns configured duration', () async {
        final provider = MockAudioDataProvider(duration: 45);
        await provider.initialize();

        expect(provider.getDuration(), 45);
      });
    });

    group('getAmplitudeAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 100; frame += 10) {
          final amplitude = provider.getAmplitudeAt(frame);
          expect(amplitude, greaterThanOrEqualTo(0.0));
          expect(amplitude, lessThanOrEqualTo(1.0));
        }
      });

      test('respects fps parameter', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        // Same time point at different fps should give similar-ish results
        // (not exact due to sampling)
        final amp30 = provider.getAmplitudeAt(30, fps: 30); // 1 second
        final amp60 = provider.getAmplitudeAt(60, fps: 60); // 1 second

        // Both should be valid values
        expect(amp30, greaterThanOrEqualTo(0.0));
        expect(amp60, greaterThanOrEqualTo(0.0));
      });

      test('returns consistent values with same seed', () async {
        final provider1 = MockAudioDataProvider(seed: 100);
        final provider2 = MockAudioDataProvider(seed: 100);
        await provider1.initialize();
        await provider2.initialize();

        for (var frame = 0; frame < 50; frame += 5) {
          expect(
            provider1.getAmplitudeAt(frame),
            provider2.getAmplitudeAt(frame),
          );
        }
      });

      test('clamps to valid range at edges', () async {
        final provider = MockAudioDataProvider(duration: 10);
        await provider.initialize();

        // Very large frame number should be clamped
        final amplitude = provider.getAmplitudeAt(10000, fps: 30);
        expect(amplitude, greaterThanOrEqualTo(0.0));
        expect(amplitude, lessThanOrEqualTo(1.0));
      });
    });

    group('getBeatStrengthAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 100; frame += 5) {
          final strength = provider.getBeatStrengthAt(frame);
          expect(strength, greaterThanOrEqualTo(0.0));
          expect(strength, lessThanOrEqualTo(1.0));
        }
      });

      test('has higher values at beat positions', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        // At 120 BPM and 30 fps, beats should be at approximately frame 15 intervals
        // (60 seconds / 120 beats = 0.5 seconds per beat = 15 frames at 30 fps)
        final beatStrengthAtBeat = provider.getBeatStrengthAt(0);
        final beatStrengthMidway = provider.getBeatStrengthAt(7);

        // Beat should have higher strength at beat position
        expect(beatStrengthAtBeat, greaterThan(beatStrengthMidway));
      });
    });

    group('isBeatAt', () {
      test('returns true at beat positions', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        // First beat should be detected
        expect(provider.isBeatAt(0, threshold: 0.5), isTrue);
      });

      test('respects threshold parameter', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        // Lower threshold should detect more beats
        var lowThresholdBeats = 0;
        var highThresholdBeats = 0;

        for (var frame = 0; frame < 300; frame++) {
          if (provider.isBeatAt(frame, threshold: 0.3)) lowThresholdBeats++;
          if (provider.isBeatAt(frame, threshold: 0.8)) highThresholdBeats++;
        }

        expect(lowThresholdBeats, greaterThanOrEqualTo(highThresholdBeats));
      });
    });

    group('getFrequencyBandsAt', () {
      test('returns correct number of bands', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        final bands8 = provider.getFrequencyBandsAt(0, bandCount: 8);
        final bands16 = provider.getFrequencyBandsAt(0, bandCount: 16);

        expect(bands8.length, 8);
        expect(bands16.length, 16);
      });

      test('all values are between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 100; frame += 10) {
          final bands = provider.getFrequencyBandsAt(frame);
          for (final value in bands) {
            expect(value, greaterThanOrEqualTo(0.0));
            expect(value, lessThanOrEqualTo(1.0));
          }
        }
      });

      test('bass bands respond to beats', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        // At a beat position
        final bandsAtBeat = provider.getFrequencyBandsAt(0);
        // Between beats
        final bandsBetween = provider.getFrequencyBandsAt(7);

        // Bass (lower bands) should be higher at beat positions
        final bassAtBeat = bandsAtBeat.take(3).reduce((a, b) => a + b) / 3;
        final bassBetween = bandsBetween.take(3).reduce((a, b) => a + b) / 3;

        expect(bassAtBeat, greaterThanOrEqualTo(bassBetween * 0.5));
      });
    });

    group('getBassAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 100; frame += 10) {
          final bass = provider.getBassAt(frame);
          expect(bass, greaterThanOrEqualTo(0.0));
          expect(bass, lessThanOrEqualTo(1.0));
        }
      });

      test('is average of lower frequency bands', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        final bands = provider.getFrequencyBandsAt(0);
        final bass = provider.getBassAt(0);

        // Bass should be average of first third of bands
        final third = bands.length ~/ 3;
        final expectedBass = bands.take(third).reduce((a, b) => a + b) / third;

        expect(bass, closeTo(expectedBass, 0.01));
      });
    });

    group('getMidAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 100; frame += 10) {
          final mid = provider.getMidAt(frame);
          expect(mid, greaterThanOrEqualTo(0.0));
          expect(mid, lessThanOrEqualTo(1.0));
        }
      });
    });

    group('getTrebleAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 100; frame += 10) {
          final treble = provider.getTrebleAt(frame);
          expect(treble, greaterThanOrEqualTo(0.0));
          expect(treble, lessThanOrEqualTo(1.0));
        }
      });
    });

    group('getAllBeatFrames', () {
      test('returns beats at expected intervals', () async {
        final provider = MockAudioDataProvider(bpm: 120, duration: 10);
        await provider.initialize();

        final beats = provider.getAllBeatFrames(fps: 30);

        // At 120 BPM, we should have 2 beats per second
        // For 10 seconds, that's 20 beats
        expect(beats.length, closeTo(20, 2));

        // First beat should be at frame 0
        expect(beats.first, 0);

        // Beats should be approximately 15 frames apart (30fps / 2bps = 15)
        for (var i = 1; i < beats.length; i++) {
          final interval = beats[i] - beats[i - 1];
          expect(interval, closeTo(15, 2));
        }
      });

      test('respects fps parameter', () async {
        final provider = MockAudioDataProvider(bpm: 60, duration: 5);
        await provider.initialize();

        final beats30 = provider.getAllBeatFrames(fps: 30);
        final beats60 = provider.getAllBeatFrames(fps: 60);

        // At 60 BPM, 1 beat per second
        // At 30 fps: 5 seconds = 5 beats at frames 0, 30, 60, 90, 120
        // At 60 fps: 5 seconds = 5 beats at frames 0, 60, 120, 180, 240
        expect(beats60.length, beats30.length);

        // Frame numbers should be doubled for 60fps
        for (var i = 0; i < beats30.length; i++) {
          expect(beats60[i], closeTo(beats30[i] * 2, 2));
        }
      });
    });

    group('getNextBeatFrame', () {
      test('returns next beat after current frame', () async {
        final provider = MockAudioDataProvider(bpm: 120, duration: 10);
        await provider.initialize();

        final beats = provider.getAllBeatFrames(fps: 30);
        final nextBeat = provider.getNextBeatFrame(0, fps: 30);

        // Should return second beat (first beat after frame 0)
        expect(nextBeat, beats[1]);
      });

      test('returns null when no more beats', () async {
        final provider = MockAudioDataProvider(bpm: 120, duration: 1);
        await provider.initialize();

        final nextBeat = provider.getNextBeatFrame(1000, fps: 30);

        expect(nextBeat, isNull);
      });

      test('skips current frame if on a beat', () async {
        final provider = MockAudioDataProvider(bpm: 120, duration: 10);
        await provider.initialize();

        final beats = provider.getAllBeatFrames(fps: 30);

        // If we're on the first beat, should return the second
        final nextBeat = provider.getNextBeatFrame(beats[0], fps: 30);
        expect(nextBeat, beats[1]);
      });
    });

    group('reproducibility', () {
      test('same seed produces identical data', () async {
        final provider1 = MockAudioDataProvider(
          bpm: 100,
          duration: 10,
          seed: 12345,
        );
        final provider2 = MockAudioDataProvider(
          bpm: 100,
          duration: 10,
          seed: 12345,
        );

        await provider1.initialize();
        await provider2.initialize();

        for (var frame = 0; frame < 100; frame += 5) {
          expect(
            provider1.getAmplitudeAt(frame),
            provider2.getAmplitudeAt(frame),
          );
          expect(
            provider1.getBeatStrengthAt(frame),
            provider2.getBeatStrengthAt(frame),
          );
        }
      });

      test('different seeds produce different data', () async {
        final provider1 = MockAudioDataProvider(seed: 1);
        final provider2 = MockAudioDataProvider(seed: 2);

        await provider1.initialize();
        await provider2.initialize();

        var differences = 0;
        for (var frame = 0; frame < 100; frame += 5) {
          if (provider1.getAmplitudeAt(frame) !=
              provider2.getAmplitudeAt(frame)) {
            differences++;
          }
        }

        // Most frames should have different values
        expect(differences, greaterThan(10));
      });
    });

    group('edge cases', () {
      test('handles very short duration', () async {
        final provider = MockAudioDataProvider(duration: 0.1);
        await provider.initialize();

        expect(provider.getAmplitudeAt(0), greaterThanOrEqualTo(0.0));
        // Very short duration may have zero or more beats
        expect(provider.getAllBeatFrames(), isA<List<int>>());
      });

      test('handles very slow BPM', () async {
        final provider = MockAudioDataProvider(bpm: 30, duration: 10);
        await provider.initialize();

        final beats = provider.getAllBeatFrames(fps: 30);

        // At 30 BPM, 0.5 beats per second, so 5 beats in 10 seconds
        expect(beats.length, closeTo(5, 1));
      });

      test('handles very fast BPM', () async {
        final provider = MockAudioDataProvider(bpm: 240, duration: 5);
        await provider.initialize();

        final beats = provider.getAllBeatFrames(fps: 30);

        // At 240 BPM, 4 beats per second, so 20 beats in 5 seconds
        expect(beats.length, closeTo(20, 2));
      });

      test('handles zero amplitude variation', () async {
        final provider = MockAudioDataProvider(amplitudeVariation: 0);
        await provider.initialize();

        // All amplitudes should be around 0.5 (base value)
        for (var frame = 0; frame < 100; frame += 10) {
          expect(provider.getAmplitudeAt(frame), closeTo(0.5, 0.1));
        }
      });

      test('handles maximum amplitude variation', () async {
        final provider = MockAudioDataProvider(amplitudeVariation: 1.0);
        await provider.initialize();

        // Values should still be clamped to 0-1
        for (var frame = 0; frame < 100; frame += 10) {
          final amp = provider.getAmplitudeAt(frame);
          expect(amp, greaterThanOrEqualTo(0.0));
          expect(amp, lessThanOrEqualTo(1.0));
        }
      });

      test('handles frame 0', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        expect(() => provider.getAmplitudeAt(0), returnsNormally);
        expect(() => provider.getBeatStrengthAt(0), returnsNormally);
        expect(() => provider.getFrequencyBandsAt(0), returnsNormally);
      });
    });
  });
}
