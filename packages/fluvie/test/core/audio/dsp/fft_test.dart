import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/dsp/fft.dart';

/// Generates [n] samples of a cosine at [cycles] full cycles across the window
/// (so its energy lands exactly in FFT bin [cycles]).
Float64List _cosine(int n, int cycles, {double amplitude = 1.0}) {
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = amplitude * math.cos(2 * math.pi * cycles * i / n);
  }
  return out;
}

/// The index of the largest value in [magnitudes].
int _peakBin(Float64List magnitudes) {
  var best = 0;
  for (var i = 1; i < magnitudes.length; i++) {
    if (magnitudes[i] > magnitudes[best]) best = i;
  }
  return best;
}

void main() {
  group('fftMagnitudes peaks at the signal bin', () {
    test('a 5-cycle cosine over 64 samples peaks at bin 5', () {
      final mags = fftMagnitudes(_cosine(64, 5));
      expect(_peakBin(mags), 5);
    });

    test('an 11-cycle cosine over 256 samples peaks at bin 11', () {
      final mags = fftMagnitudes(_cosine(256, 11));
      expect(_peakBin(mags), 11);
    });

    test('returns half the window plus one bins (0..N/2)', () {
      final mags = fftMagnitudes(_cosine(64, 5));
      expect(mags.length, 64 ~/ 2 + 1);
    });

    test('a DC (constant) signal peaks at bin 0', () {
      final mags = fftMagnitudes(Float64List.fromList(List.filled(32, 0.5)));
      expect(_peakBin(mags), 0);
    });
  });

  group('fft round-trip and Parseval sanity', () {
    test('the forward transform conserves energy (Parseval)', () {
      final input = _cosine(64, 7, amplitude: 0.8);
      final (:re, :im) = fft(input);
      var timeEnergy = 0.0;
      for (final value in input) {
        timeEnergy += value * value;
      }
      var freqEnergy = 0.0;
      for (var i = 0; i < re.length; i++) {
        freqEnergy += re[i] * re[i] + im[i] * im[i];
      }
      // Parseval for the DFT: sum|x|^2 == (1/N) sum|X|^2.
      expect(freqEnergy / input.length, closeTo(timeEnergy, 1e-6));
    });

    test('the imaginary part of an even (cosine) signal is ~0', () {
      final (:re, :im) = fft(_cosine(64, 5));
      for (final value in im) {
        expect(value.abs(), lessThan(1e-6));
      }
    });
  });

  group('fft rejects non-power-of-two lengths', () {
    test('length 100 throws an ArgumentError', () {
      expect(() => fft(Float64List(100)), throwsArgumentError);
    });

    test('length 0 throws an ArgumentError', () {
      expect(() => fft(Float64List(0)), throwsArgumentError);
    });
  });

  group('fft determinism', () {
    test('transforming the same input twice is identical', () {
      final input = _cosine(128, 9);
      final first = fftMagnitudes(input);
      final second = fftMagnitudes(input);
      expect(first, orderedEquals(second));
    });
  });

  group('hannWindow', () {
    test('its endpoints are exactly zero', () {
      final window = hannWindow(64);
      expect(window.first, 0.0);
      expect(window.last, 0.0);
    });

    test('it peaks at ~1.0 in the middle of the window', () {
      // A symmetric Hann of even size peaks between its two center samples, so
      // both straddle 1.0; the odd-size center sample hits 1.0 exactly.
      final even = hannWindow(64);
      expect(even[32], closeTo(1.0, 1e-3));
      final odd = hannWindow(65);
      expect(odd[32], closeTo(1.0, 1e-12));
    });

    test('it is symmetric', () {
      final window = hannWindow(64);
      for (var i = 0; i < window.length; i++) {
        expect(window[i], closeTo(window[window.length - 1 - i], 1e-12));
      }
    });

    test('applyHann multiplies a signal by the window pointwise', () {
      final signal = Float64List(8)..fillRange(0, 8, 1);
      final windowed = applyHann(signal);
      final window = hannWindow(8);
      for (var i = 0; i < signal.length; i++) {
        expect(windowed[i], closeTo(window[i], 1e-12));
      }
    });
  });

  group('bandEnergies partition the spectrum', () {
    test('every magnitude bin lands in exactly one band sum', () {
      // A flat spectrum: each band sum is its bin count, and the three sums
      // add up to the total of the analysable bins (1..N/2, DC excluded).
      final mags = Float64List(513)..fillRange(0, 513, 1); // 1024-pt window
      final bands = bandEnergies(mags, sampleRate: 44100, windowSize: 1024);
      final total = bands.bass + bands.mid + bands.treble;
      // Bins 1..512 are partitioned across the three ranges (DC bin 0 excluded).
      expect(total, closeTo(512, 1e-9));
    });

    test('energy concentrated in low bins reads as bass', () {
      final mags = Float64List(513);
      mags[2] = 10.0; // ~86 Hz at 44100/1024
      final bands = bandEnergies(mags, sampleRate: 44100, windowSize: 1024);
      expect(bands.bass, greaterThan(bands.mid));
      expect(bands.bass, greaterThan(bands.treble));
    });

    test('energy concentrated in high bins reads as treble', () {
      final mags = Float64List(513);
      mags[400] = 10.0; // ~17 kHz
      final bands = bandEnergies(mags, sampleRate: 44100, windowSize: 1024);
      expect(bands.treble, greaterThan(bands.bass));
      expect(bands.treble, greaterThan(bands.mid));
    });

    test('is deterministic', () {
      final mags = Float64List.fromList(List.generate(513, (i) => i.toDouble()));
      final first = bandEnergies(mags, sampleRate: 44100, windowSize: 1024);
      final second = bandEnergies(mags, sampleRate: 44100, windowSize: 1024);
      expect(first, second);
    });
  });
}
