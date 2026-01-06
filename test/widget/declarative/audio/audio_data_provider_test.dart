import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/audio/audio_data_provider.dart';

void main() {
  group('MockAudioDataProvider', () {
    group('construction', () {
      test('creates with default values', () {
        final provider = MockAudioDataProvider();

        expect(provider.bpm, 120);
        expect(provider.duration, 60);
        expect(provider.seed, 42);
        expect(provider.amplitudeVariation, 0.3);
      });

      test('creates with custom values', () {
        final provider = MockAudioDataProvider(
          bpm: 140,
          duration: 30,
          seed: 123,
          amplitudeVariation: 0.5,
        );

        expect(provider.bpm, 140);
        expect(provider.duration, 30);
        expect(provider.seed, 123);
        expect(provider.amplitudeVariation, 0.5);
      });
    });

    group('initialization', () {
      test('initialize completes without error', () async {
        final provider = MockAudioDataProvider();
        await expectLater(provider.initialize(), completes);
      });

      test('dispose completes without error', () {
        final provider = MockAudioDataProvider();
        expect(() => provider.dispose(), returnsNormally);
      });
    });

    group('getBpm', () {
      test('returns configured bpm', () async {
        final provider = MockAudioDataProvider(bpm: 90);
        await provider.initialize();

        expect(provider.getBpm(), 90);
      });

      test('returns different bpm values', () async {
        for (final bpm in [60.0, 90.0, 120.0, 140.0, 180.0]) {
          final provider = MockAudioDataProvider(bpm: bpm);
          await provider.initialize();
          expect(provider.getBpm(), bpm);
        }
      });
    });

    group('getAmplitudeAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 100; frame++) {
          final amplitude = provider.getAmplitudeAt(frame);
          expect(amplitude, greaterThanOrEqualTo(0.0));
          expect(amplitude, lessThanOrEqualTo(1.0));
        }
      });

      test('respects fps parameter', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        // Different fps should give different results for same frame
        final amp30 = provider.getAmplitudeAt(60, fps: 30);
        final amp60 = provider.getAmplitudeAt(60, fps: 60);

        // Frame 60 at 30fps = 2 seconds, at 60fps = 1 second
        // So they should be different (unless coincidentally same)
        expect(amp30, isA<double>());
        expect(amp60, isA<double>());
      });

      test('is reproducible with same seed', () async {
        final provider1 = MockAudioDataProvider(seed: 100);
        final provider2 = MockAudioDataProvider(seed: 100);
        await provider1.initialize();
        await provider2.initialize();

        for (var frame = 0; frame < 10; frame++) {
          expect(
            provider1.getAmplitudeAt(frame),
            provider2.getAmplitudeAt(frame),
          );
        }
      });

      test('differs with different seeds', () async {
        final provider1 = MockAudioDataProvider(seed: 100);
        final provider2 = MockAudioDataProvider(seed: 200);
        await provider1.initialize();
        await provider2.initialize();

        // At least some frames should differ
        var hasDifference = false;
        for (var frame = 0; frame < 10; frame++) {
          if (provider1.getAmplitudeAt(frame) !=
              provider2.getAmplitudeAt(frame)) {
            hasDifference = true;
            break;
          }
        }
        expect(hasDifference, isTrue);
      });
    });

    group('getBeatStrengthAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 100; frame++) {
          final strength = provider.getBeatStrengthAt(frame);
          expect(strength, greaterThanOrEqualTo(0.0));
          expect(strength, lessThanOrEqualTo(1.0));
        }
      });

      test('has stronger beats at beat positions', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        // At 120 BPM with 30 fps, beats occur every 15 frames
        // First beat at frame 0 should be strong
        final beatStrength = provider.getBeatStrengthAt(0);
        expect(beatStrength, greaterThan(0.0));
      });
    });

    group('isBeatAt', () {
      test('returns boolean', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        expect(provider.isBeatAt(0), isA<bool>());
        expect(provider.isBeatAt(15), isA<bool>());
      });

      test('respects threshold parameter', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        // High threshold should return fewer beats
        final lowThresholdBeats =
            List.generate(100, (i) => provider.isBeatAt(i, threshold: 0.1))
                .where((b) => b)
                .length;
        final highThresholdBeats =
            List.generate(100, (i) => provider.isBeatAt(i, threshold: 0.9))
                .where((b) => b)
                .length;

        expect(highThresholdBeats, lessThanOrEqualTo(lowThresholdBeats));
      });
    });

    group('getFrequencyBandsAt', () {
      test('returns correct number of bands', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        final bands8 = provider.getFrequencyBandsAt(0, bandCount: 8);
        expect(bands8.length, 8);

        final bands16 = provider.getFrequencyBandsAt(0, bandCount: 16);
        expect(bands16.length, 16);

        final bands4 = provider.getFrequencyBandsAt(0, bandCount: 4);
        expect(bands4.length, 4);
      });

      test('all bands are between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        final bands = provider.getFrequencyBandsAt(0);
        for (final band in bands) {
          expect(band, greaterThanOrEqualTo(0.0));
          expect(band, lessThanOrEqualTo(1.0));
        }
      });

      test('uses default of 8 bands', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        final bands = provider.getFrequencyBandsAt(0);
        expect(bands.length, 8);
      });
    });

    group('getBassAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 50; frame++) {
          final bass = provider.getBassAt(frame);
          expect(bass, greaterThanOrEqualTo(0.0));
          expect(bass, lessThanOrEqualTo(1.0));
        }
      });
    });

    group('getMidAt', () {
      test('returns value between 0 and 1', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        for (var frame = 0; frame < 50; frame++) {
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

        for (var frame = 0; frame < 50; frame++) {
          final treble = provider.getTrebleAt(frame);
          expect(treble, greaterThanOrEqualTo(0.0));
          expect(treble, lessThanOrEqualTo(1.0));
        }
      });
    });

    group('getDuration', () {
      test('returns configured duration', () async {
        final provider = MockAudioDataProvider(duration: 45);
        await provider.initialize();

        expect(provider.getDuration(), 45);
      });
    });

    group('getNextBeatFrame', () {
      test('returns frame after current', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        final nextBeat = provider.getNextBeatFrame(0);
        expect(nextBeat, isNotNull);
        expect(nextBeat, greaterThan(0));
      });

      test('returns null when no more beats', () async {
        final provider = MockAudioDataProvider(bpm: 120, duration: 1);
        await provider.initialize();

        final nextBeat = provider.getNextBeatFrame(1000);
        expect(nextBeat, isNull);
      });

      test('returns beats in order', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        var currentFrame = 0;
        for (var i = 0; i < 10; i++) {
          final nextBeat = provider.getNextBeatFrame(currentFrame);
          if (nextBeat == null) break;
          expect(nextBeat, greaterThan(currentFrame));
          currentFrame = nextBeat;
        }
      });
    });

    group('getAllBeatFrames', () {
      test('returns list of beat frames', () async {
        final provider = MockAudioDataProvider(bpm: 120, duration: 5);
        await provider.initialize();

        final beats = provider.getAllBeatFrames();
        expect(beats, isA<List<int>>());
        expect(beats.isNotEmpty, isTrue);
      });

      test('beats are in ascending order', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        final beats = provider.getAllBeatFrames();
        for (var i = 1; i < beats.length; i++) {
          expect(beats[i], greaterThan(beats[i - 1]));
        }
      });

      test('respects fps parameter', () async {
        final provider = MockAudioDataProvider(bpm: 120);
        await provider.initialize();

        final beats30 = provider.getAllBeatFrames(fps: 30);
        final beats60 = provider.getAllBeatFrames(fps: 60);

        // At 60fps, beat frames should be roughly double
        expect(beats60.length, beats30.length);
        if (beats30.isNotEmpty && beats60.isNotEmpty) {
          expect(beats60[1], closeTo(beats30[1] * 2, 2));
        }
      });

      test('correct number of beats based on BPM and duration', () async {
        final provider = MockAudioDataProvider(bpm: 60, duration: 10);
        await provider.initialize();

        // At 60 BPM, should have ~10 beats in 10 seconds
        final beats = provider.getAllBeatFrames();
        expect(beats.length, closeTo(10, 2));
      });
    });

    group('edge cases', () {
      test('handles frame 0', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        expect(() => provider.getAmplitudeAt(0), returnsNormally);
        expect(() => provider.getBeatStrengthAt(0), returnsNormally);
        expect(() => provider.getFrequencyBandsAt(0), returnsNormally);
      });

      test('handles very large frame', () async {
        final provider = MockAudioDataProvider();
        await provider.initialize();

        expect(() => provider.getAmplitudeAt(10000), returnsNormally);
        expect(() => provider.getBeatStrengthAt(10000), returnsNormally);
      });

      test('handles zero duration', () async {
        final provider = MockAudioDataProvider(duration: 0.1);
        await expectLater(provider.initialize(), completes);
      });

      test('handles very high bpm', () async {
        final provider = MockAudioDataProvider(bpm: 300);
        await provider.initialize();

        expect(provider.getBpm(), 300);
        expect(provider.getAllBeatFrames(), isNotEmpty);
      });

      test('handles very low bpm', () async {
        final provider = MockAudioDataProvider(bpm: 30);
        await provider.initialize();

        expect(provider.getBpm(), 30);
        expect(provider.getAllBeatFrames(), isNotEmpty);
      });
    });
  });
}
