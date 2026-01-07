import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/audio/frequency_analyzer.dart';

void main() {
  group('FrequencyAnalyzer', () {
    group('construction', () {
      test('creates with default parameters', () {
        final analyzer = FrequencyAnalyzer();

        expect(analyzer.bandCount, 8);
        expect(analyzer.fftSize, 1024);
        expect(analyzer.smoothing, 0.3);
      });

      test('creates with custom parameters', () {
        final analyzer = FrequencyAnalyzer(
          bandCount: 16,
          fftSize: 2048,
          smoothing: 0.5,
        );

        expect(analyzer.bandCount, 16);
        expect(analyzer.fftSize, 2048);
        expect(analyzer.smoothing, 0.5);
      });

      test('asserts bandCount is positive', () {
        expect(
          () => FrequencyAnalyzer(bandCount: 0),
          throwsA(isA<AssertionError>()),
        );
      });

      test('asserts fftSize is power of 2', () {
        expect(
          () => FrequencyAnalyzer(fftSize: 1000),
          throwsA(isA<AssertionError>()),
        );
      });

      test('accepts valid power of 2 fftSize', () {
        expect(
          () => FrequencyAnalyzer(fftSize: 512),
          returnsNormally,
        );
        expect(
          () => FrequencyAnalyzer(fftSize: 2048),
          returnsNormally,
        );
      });
    });

    group('analyze', () {
      test('returns bands for valid input', () {
        final analyzer = FrequencyAnalyzer();
        final samples = _generateSineWave(440, 44100, 1024);

        final bands = analyzer.analyze(samples, sampleRate: 44100);

        expect(bands.length, 8);
        expect(bands.values.length, 8);
      });

      test('pads short samples with zeros', () {
        final analyzer = FrequencyAnalyzer(fftSize: 1024);
        final samples = Float64List.fromList([0.5, -0.5, 0.3, -0.2]);

        // Should not throw
        final bands = analyzer.analyze(samples, sampleRate: 44100);

        expect(bands.length, 8);
      });

      test('detects low frequency in bass band', () {
        final analyzer = FrequencyAnalyzer(bandCount: 8);

        // 100 Hz sine wave - should be in bass range
        final samples = _generateSineWave(100, 44100, 2048);

        final bands = analyzer.analyze(samples, sampleRate: 44100);

        // Bass should have significant energy
        expect(bands.bass, greaterThan(0.1));
      });

      test('detects high frequency in treble band', () {
        final analyzer = FrequencyAnalyzer(bandCount: 8);

        // 8000 Hz sine wave - should be in treble range
        final samples = _generateSineWave(8000, 44100, 2048);

        final bands = analyzer.analyze(samples, sampleRate: 44100);

        // Treble should have energy
        expect(bands.treble, greaterThan(0));
      });

      test('returns normalized values between 0 and 1', () {
        final analyzer = FrequencyAnalyzer();
        final samples = _generateSineWave(440, 44100, 1024);

        final bands = analyzer.analyze(samples, sampleRate: 44100);

        for (final value in bands.values) {
          expect(value, greaterThanOrEqualTo(0.0));
          expect(value, lessThanOrEqualTo(1.0));
        }
      });

      test('handles silent audio', () {
        final analyzer = FrequencyAnalyzer();
        final samples = Float64List(1024); // All zeros

        final bands = analyzer.analyze(samples, sampleRate: 44100);

        // All bands should be 0 for silence
        for (final value in bands.values) {
          expect(value, 0.0);
        }
      });

      test('applies smoothing between calls', () {
        final analyzer = FrequencyAnalyzer(smoothing: 0.5);

        // First analysis with signal
        final samples1 = _generateSineWave(440, 44100, 1024);
        analyzer.analyze(samples1, sampleRate: 44100);

        // Second analysis with silence
        final samples2 = Float64List(1024);
        final bands2 = analyzer.analyze(samples2, sampleRate: 44100);

        // With smoothing, bands2 should retain some of bands1's values
        // (won't be zero even though input is silent)
        final hasNonZero = bands2.values.any((v) => v > 0);
        expect(hasNonZero, isTrue);
      });
    });

    group('analyzeAt', () {
      test('analyzes at specific time', () {
        final analyzer = FrequencyAnalyzer(fftSize: 512);
        const sampleRate = 44100;

        // Create 2 seconds of audio
        final samples = _generateSineWave(440, sampleRate, sampleRate * 2);

        // Analyze at 0.5 seconds
        final bands = analyzer.analyzeAt(
          samples,
          0.5,
          sampleRate: sampleRate,
        );

        expect(bands.length, 8);
      });

      test('returns empty bands for negative time', () {
        final analyzer = FrequencyAnalyzer();
        final samples = _generateSineWave(440, 44100, 44100);

        final bands = analyzer.analyzeAt(
          samples,
          -1.0,
          sampleRate: 44100,
        );

        expect(bands.amplitude, 0.0);
      });

      test('returns empty bands for time beyond audio length', () {
        final analyzer = FrequencyAnalyzer();
        final samples = _generateSineWave(440, 44100, 44100);

        final bands = analyzer.analyzeAt(
          samples,
          5.0, // 5 seconds, but only 1 second of audio
          sampleRate: 44100,
        );

        expect(bands.amplitude, 0.0);
      });
    });

    group('analyzeAtFrame', () {
      test('converts frame to time and analyzes', () {
        final analyzer = FrequencyAnalyzer(fftSize: 512);
        const sampleRate = 44100;
        const fps = 30;

        // Create 2 seconds of audio
        final samples = _generateSineWave(440, sampleRate, sampleRate * 2);

        // Analyze at frame 15 (0.5 seconds at 30 fps)
        final bands = analyzer.analyzeAtFrame(
          samples,
          15,
          fps: fps,
          sampleRate: sampleRate,
        );

        expect(bands.length, 8);
      });

      test('frame 0 analyzes start of audio', () {
        final analyzer = FrequencyAnalyzer();
        final samples = _generateSineWave(440, 44100, 44100);

        final bands = analyzer.analyzeAtFrame(
          samples,
          0,
          fps: 30,
          sampleRate: 44100,
        );

        expect(bands.amplitude, greaterThan(0));
      });
    });

    group('reset', () {
      test('clears smoothing state', () {
        final analyzer = FrequencyAnalyzer(smoothing: 0.9);

        // First analysis with signal
        final samples1 = _generateSineWave(440, 44100, 1024);
        analyzer.analyze(samples1, sampleRate: 44100);

        // Reset
        analyzer.reset();

        // Analysis with silence should now be zero (no smoothing history)
        final samples2 = Float64List(1024);
        final bands2 = analyzer.analyze(samples2, sampleRate: 44100);

        for (final value in bands2.values) {
          expect(value, 0.0);
        }
      });
    });
  });

  group('FrequencyBands', () {
    group('construction', () {
      test('creates from list', () {
        const bands = FrequencyBands([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]);

        expect(bands.length, 8);
        expect(bands[0], 0.1);
        expect(bands[7], 0.8);
      });

      test('creates empty bands', () {
        final bands = FrequencyBands.empty(8);

        expect(bands.length, 8);
        for (final value in bands.values) {
          expect(value, 0.0);
        }
      });
    });

    group('bass', () {
      test('calculates average of lowest third', () {
        // 9 bands: bass is first 3
        const bands = FrequencyBands([
          0.9,
          0.6,
          0.3, // bass: avg = 0.6
          0.1,
          0.1,
          0.1, // mid
          0.1,
          0.1,
          0.1, // treble
        ]);

        expect(bands.bass, closeTo(0.6, 0.01));
      });

      test('returns 0 for empty bands', () {
        const bands = FrequencyBands([]);

        expect(bands.bass, 0.0);
      });
    });

    group('mid', () {
      test('calculates average of middle third', () {
        // 9 bands: mid is middle 3
        const bands = FrequencyBands([
          0.1,
          0.1,
          0.1, // bass
          0.6,
          0.9,
          0.3, // mid: avg = 0.6
          0.1,
          0.1,
          0.1, // treble
        ]);

        expect(bands.mid, closeTo(0.6, 0.01));
      });

      test('returns 0 for empty bands', () {
        const bands = FrequencyBands([]);

        expect(bands.mid, 0.0);
      });
    });

    group('treble', () {
      test('calculates average of highest third', () {
        // 9 bands: treble is last 3
        const bands = FrequencyBands([
          0.1,
          0.1,
          0.1, // bass
          0.1,
          0.1,
          0.1, // mid
          0.3,
          0.6,
          0.9, // treble: avg = 0.6
        ]);

        expect(bands.treble, closeTo(0.6, 0.01));
      });

      test('returns 0 for empty bands', () {
        const bands = FrequencyBands([]);

        expect(bands.treble, 0.0);
      });
    });

    group('amplitude', () {
      test('calculates average of all bands', () {
        const bands = FrequencyBands([0.2, 0.4, 0.6, 0.8]);

        expect(bands.amplitude, 0.5);
      });

      test('returns 0 for empty bands', () {
        const bands = FrequencyBands([]);

        expect(bands.amplitude, 0.0);
      });
    });

    group('peak', () {
      test('returns maximum value', () {
        const bands = FrequencyBands([0.1, 0.3, 0.9, 0.5, 0.2]);

        expect(bands.peak, 0.9);
      });

      test('returns 0 for empty bands', () {
        const bands = FrequencyBands([]);

        expect(bands.peak, 0.0);
      });
    });

    group('operator []', () {
      test('returns value at index', () {
        const bands = FrequencyBands([0.1, 0.2, 0.3]);

        expect(bands[0], 0.1);
        expect(bands[1], 0.2);
        expect(bands[2], 0.3);
      });
    });

    group('toString', () {
      test('includes values', () {
        const bands = FrequencyBands([0.5, 0.8]);

        expect(bands.toString(), contains('0.5'));
        expect(bands.toString(), contains('0.8'));
      });
    });
  });
}

/// Generates a sine wave at the specified frequency.
Float64List _generateSineWave(double frequency, int sampleRate, int length) {
  final samples = Float64List(length);

  for (var i = 0; i < length; i++) {
    final t = i / sampleRate;
    samples[i] = math.sin(2 * math.pi * frequency * t);
  }

  return samples;
}
