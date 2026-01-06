import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/audio/bpm_detector.dart';

void main() {
  group('BpmDetector', () {
    group('construction', () {
      test('creates with default parameters', () {
        const detector = BpmDetector();

        expect(detector.minBpm, 60);
        expect(detector.maxBpm, 180);
        expect(detector.intervalCount, 20);
      });

      test('creates with custom parameters', () {
        const detector = BpmDetector(
          minBpm: 80,
          maxBpm: 200,
          intervalCount: 10,
        );

        expect(detector.minBpm, 80);
        expect(detector.maxBpm, 200);
        expect(detector.intervalCount, 10);
      });
    });

    group('detect', () {
      test('returns 0 for empty samples', () {
        const detector = BpmDetector();
        final samples = Float64List(0);

        final bpm = detector.detect(samples, sampleRate: 44100);

        expect(bpm, 0);
      });

      test('returns 0 for very short samples', () {
        const detector = BpmDetector();
        final samples = Float64List.fromList([0.5, -0.5, 0.3]);

        final bpm = detector.detect(samples, sampleRate: 44100);

        expect(bpm, 0);
      });

      test('detects BPM from synthetic beat pattern', () {
        const detector = BpmDetector();
        const sampleRate = 44100;
        const targetBpm = 120.0;

        // Generate 5 seconds of audio with beats at 120 BPM
        final samples = _generateBeats(
          bpm: targetBpm,
          durationSeconds: 5,
          sampleRate: sampleRate,
        );

        final bpm = detector.detect(samples, sampleRate: sampleRate);

        // Should detect within 10% of target BPM
        expect(bpm, closeTo(targetBpm, targetBpm * 0.1));
      });

      test('detects slower tempo (80 BPM)', () {
        const detector = BpmDetector(minBpm: 60, maxBpm: 120);
        const sampleRate = 44100;
        const targetBpm = 80.0;

        final samples = _generateBeats(
          bpm: targetBpm,
          durationSeconds: 5,
          sampleRate: sampleRate,
        );

        final bpm = detector.detect(samples, sampleRate: sampleRate);

        expect(bpm, closeTo(targetBpm, targetBpm * 0.15));
      });

      test('detects faster tempo (150 BPM)', () {
        const detector = BpmDetector(minBpm: 100, maxBpm: 200);
        const sampleRate = 44100;
        const targetBpm = 150.0;

        final samples = _generateBeats(
          bpm: targetBpm,
          durationSeconds: 5,
          sampleRate: sampleRate,
        );

        final bpm = detector.detect(samples, sampleRate: sampleRate);

        expect(bpm, closeTo(targetBpm, targetBpm * 0.15));
      });

      test('clamps result to minBpm', () {
        const detector = BpmDetector(minBpm: 60, maxBpm: 180);

        // Generate very slow beats (30 BPM - below min)
        final samples = _generateBeats(
          bpm: 30,
          durationSeconds: 5,
          sampleRate: 44100,
        );

        final bpm = detector.detect(samples, sampleRate: 44100);

        expect(bpm, greaterThanOrEqualTo(60));
      });

      test('clamps result to maxBpm', () {
        const detector = BpmDetector(minBpm: 60, maxBpm: 180);

        // Generate very fast beats (240 BPM - above max)
        final samples = _generateBeats(
          bpm: 240,
          durationSeconds: 5,
          sampleRate: 44100,
        );

        final bpm = detector.detect(samples, sampleRate: 44100);

        expect(bpm, lessThanOrEqualTo(180));
      });

      test('handles noisy signal', () {
        const detector = BpmDetector();
        const sampleRate = 44100;

        // Generate beats with added noise
        final samples = _generateBeatsWithNoise(
          bpm: 120,
          durationSeconds: 5,
          sampleRate: sampleRate,
          noiseLevel: 0.3,
        );

        final bpm = detector.detect(samples, sampleRate: sampleRate);

        // Should still detect something reasonable
        expect(bpm, greaterThan(60));
        expect(bpm, lessThan(180));
      });

      test('handles silent audio', () {
        const detector = BpmDetector();
        final samples = Float64List(44100 * 5); // 5 seconds of silence

        final bpm = detector.detect(samples, sampleRate: 44100);

        // Should return 0 or min BPM for silent audio
        expect(bpm, lessThanOrEqualTo(60));
      });
    });

    group('detectFromTimestamps', () {
      test('returns 0 for empty timestamps', () {
        const detector = BpmDetector();

        final bpm = detector.detectFromTimestamps([]);

        expect(bpm, 0);
      });

      test('returns 0 for single timestamp', () {
        const detector = BpmDetector();

        final bpm = detector.detectFromTimestamps([0.5]);

        expect(bpm, 0);
      });

      test('detects 120 BPM from timestamps', () {
        const detector = BpmDetector();

        // 120 BPM = 0.5 seconds between beats
        final timestamps = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0];

        final bpm = detector.detectFromTimestamps(timestamps);

        expect(bpm, closeTo(120, 1));
      });

      test('detects 90 BPM from timestamps', () {
        const detector = BpmDetector();

        // 90 BPM = 0.667 seconds between beats
        final timestamps = [
          0.0,
          0.667,
          1.333,
          2.0,
          2.667,
          3.333,
          4.0,
        ];

        final bpm = detector.detectFromTimestamps(timestamps);

        expect(bpm, closeTo(90, 2));
      });

      test('handles irregular intervals', () {
        const detector = BpmDetector();

        // Slightly irregular timestamps around 100 BPM
        final timestamps = [0.0, 0.58, 1.22, 1.78, 2.42, 3.0, 3.62];

        final bpm = detector.detectFromTimestamps(timestamps);

        // Should find average tempo
        expect(bpm, greaterThan(80));
        expect(bpm, lessThan(120));
      });

      test('clamps result to BPM range', () {
        const detector = BpmDetector(minBpm: 60, maxBpm: 180);

        // 300 BPM = 0.2 seconds between beats
        final timestamps = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

        final bpm = detector.detectFromTimestamps(timestamps);

        expect(bpm, lessThanOrEqualTo(180));
      });

      test('handles zero interval', () {
        const detector = BpmDetector();

        // Same timestamp repeated
        final timestamps = [0.0, 0.0, 0.5, 1.0];

        // Should not crash
        final bpm = detector.detectFromTimestamps(timestamps);
        expect(bpm, isNotNaN);
      });
    });
  });

  group('BpmDetectionResult', () {
    group('construction', () {
      test('creates with required values', () {
        const result = BpmDetectionResult(
          bpm: 120,
          confidence: 0.85,
        );

        expect(result.bpm, 120);
        expect(result.confidence, 0.85);
        expect(result.alternatives, isEmpty);
      });

      test('creates with alternatives', () {
        const result = BpmDetectionResult(
          bpm: 120,
          confidence: 0.7,
          alternatives: [60.0, 240.0],
        );

        expect(result.alternatives, [60.0, 240.0]);
      });
    });

    group('isReliable', () {
      test('returns true for high confidence', () {
        const result = BpmDetectionResult(
          bpm: 120,
          confidence: 0.8,
        );

        expect(result.isReliable, isTrue);
      });

      test('returns true at threshold', () {
        const result = BpmDetectionResult(
          bpm: 120,
          confidence: 0.6,
        );

        expect(result.isReliable, isTrue);
      });

      test('returns false for low confidence', () {
        const result = BpmDetectionResult(
          bpm: 120,
          confidence: 0.5,
        );

        expect(result.isReliable, isFalse);
      });
    });

    group('toString', () {
      test('includes bpm and confidence', () {
        const result = BpmDetectionResult(
          bpm: 128,
          confidence: 0.92,
        );

        expect(result.toString(), contains('128'));
        expect(result.toString(), contains('0.92'));
      });
    });
  });
}

/// Generates synthetic audio with beats at specified BPM.
Float64List _generateBeats({
  required double bpm,
  required double durationSeconds,
  required int sampleRate,
}) {
  final totalSamples = (durationSeconds * sampleRate).round();
  final samples = Float64List(totalSamples);

  final beatsPerSecond = bpm / 60;
  final samplesPerBeat = sampleRate / beatsPerSecond;

  for (var i = 0; i < totalSamples; i++) {
    final beatPosition = i % samplesPerBeat;
    final beatProgress = beatPosition / samplesPerBeat;

    // Create a sharp attack with exponential decay
    if (beatProgress < 0.05) {
      // Attack phase
      samples[i] = beatProgress / 0.05;
    } else if (beatProgress < 0.3) {
      // Decay phase
      samples[i] = math.exp(-10 * (beatProgress - 0.05));
    } else {
      samples[i] = 0;
    }
  }

  return samples;
}

/// Generates beats with added noise.
Float64List _generateBeatsWithNoise({
  required double bpm,
  required double durationSeconds,
  required int sampleRate,
  required double noiseLevel,
}) {
  final samples = _generateBeats(
    bpm: bpm,
    durationSeconds: durationSeconds,
    sampleRate: sampleRate,
  );

  final random = math.Random(42);

  for (var i = 0; i < samples.length; i++) {
    samples[i] += (random.nextDouble() * 2 - 1) * noiseLevel;
    samples[i] = samples[i].clamp(-1.0, 1.0);
  }

  return samples;
}
