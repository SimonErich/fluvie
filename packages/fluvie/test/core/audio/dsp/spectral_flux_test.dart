import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/dsp/onset_detector.dart';
import 'package:fluvie/src/core/audio/dsp/spectral_flux.dart';

const int _sampleRate = 44100;

/// Builds a synthetic click track: [clickCount] short broadband bursts spaced
/// [intervalSeconds] apart over silence, at [_sampleRate]. Each click is a
/// ~12 ms decaying noise burst so it injects energy across the spectrum (a
/// strong spectral-flux spike) at a known sample position.
Float64List _clickTrack({
  required int clickCount,
  required double intervalSeconds,
}) {
  final intervalSamples = (intervalSeconds * _sampleRate).round();
  final total = intervalSamples * clickCount + intervalSamples;
  final samples = Float64List(total);
  final burstLength = (0.012 * _sampleRate).round();
  // A fixed seeded LCG so the noise is identical across runs (no dart:math
  // Random in the determinism path; this is test-local synthetic data anyway).
  var seed = 1;
  double nextNoise() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff * 2 - 1;
  }

  for (var click = 0; click < clickCount; click++) {
    final start = intervalSamples * (click + 1);
    for (var i = 0; i < burstLength && start + i < total; i++) {
      final decay = 1 - i / burstLength;
      samples[start + i] = nextNoise() * decay;
    }
  }
  return samples;
}

/// The expected hop index of a click at [seconds] given the default hop.
int _expectedHop(double seconds) => (seconds * _sampleRate / SpectralFlux.defaultHopSize).round();

void main() {
  group('spectralFlux frame math', () {
    test('emits one flux value per hop over the signal', () {
      final samples = Float64List(1024 * 4);
      final flux = spectralFlux(samples);
      // (length - window) / hop + 1 full frames.
      final expected =
          (samples.length - SpectralFlux.defaultWindowSize) ~/ SpectralFlux.defaultHopSize + 1;
      expect(flux.length, expected);
    });

    test('silence produces near-zero flux', () {
      final flux = spectralFlux(Float64List(1024 * 4));
      for (final value in flux) {
        expect(value, closeTo(0, 1e-9));
      }
    });

    test('a signal shorter than one window yields no frames', () {
      expect(spectralFlux(Float64List(512)), isEmpty);
    });

    test('is deterministic', () {
      final samples = _clickTrack(clickCount: 3, intervalSeconds: 0.5);
      expect(spectralFlux(samples), orderedEquals(spectralFlux(samples)));
    });
  });

  group('detectOnsets on a synthetic click track', () {
    test('finds an onset near each click position', () {
      final samples = _clickTrack(clickCount: 4, intervalSeconds: 0.5);
      final flux = spectralFlux(samples);
      final onsets = detectOnsets(flux);
      expect(onsets.length, 4);
      final expectedHops = [
        _expectedHop(0.5),
        _expectedHop(1),
        _expectedHop(1.5),
        _expectedHop(2),
      ];
      for (var i = 0; i < expectedHops.length; i++) {
        // The detected peak lands within a couple of hops of the click.
        expect((onsets[i] - expectedHops[i]).abs(), lessThanOrEqualTo(2));
      }
    });

    test('the adaptive threshold rejects a quiet noise floor', () {
      // Low-level white-ish noise everywhere: no peak should stand out.
      final samples = Float64List(_sampleRate * 2);
      var seed = 7;
      for (var i = 0; i < samples.length; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        samples[i] = (seed / 0x7fffffff * 2 - 1) * 0.001;
      }
      final onsets = detectOnsets(spectralFlux(samples));
      expect(onsets, isEmpty);
    });

    test('silence yields no onsets', () {
      expect(detectOnsets(spectralFlux(Float64List(_sampleRate))), isEmpty);
    });

    test('is deterministic across two identical runs', () {
      final samples = _clickTrack(clickCount: 5, intervalSeconds: 0.4);
      final flux = spectralFlux(samples);
      expect(detectOnsets(flux), orderedEquals(detectOnsets(flux)));
    });
  });

  group('onsetFramesAt maps hops to absolute video frames', () {
    test('a hop at 1.0 s maps to frame fps at the given fps', () {
      final hop = _expectedHop(1);
      final frames = onsetFramesAt(
        [hop],
        hopSize: SpectralFlux.defaultHopSize,
        sampleRate: _sampleRate,
        fps: 30,
      );
      expect(frames.single, closeTo(30, 1));
    });

    test('scales with fps', () {
      final hop = _expectedHop(2);
      final at60 = onsetFramesAt(
        [hop],
        hopSize: SpectralFlux.defaultHopSize,
        sampleRate: _sampleRate,
        fps: 60,
      );
      expect(at60.single, closeTo(120, 1));
    });

    test('preserves order and count', () {
      final frames = onsetFramesAt(
        [_expectedHop(0.5), _expectedHop(1), _expectedHop(1.5)],
        hopSize: SpectralFlux.defaultHopSize,
        sampleRate: _sampleRate,
        fps: 30,
      );
      expect(frames, hasLength(3));
      expect(frames, [
        lessThan(frames[1]),
        frames[1],
        greaterThan(frames[1]),
      ]);
    });

    test('end-to-end click track -> beat frames is deterministic', () {
      final samples = _clickTrack(clickCount: 4, intervalSeconds: 0.5);
      List<int> run() => onsetFramesAt(
        detectOnsets(spectralFlux(samples)),
        hopSize: SpectralFlux.defaultHopSize,
        sampleRate: _sampleRate,
        fps: 30,
      );
      expect(run(), orderedEquals(run()));
      // Sanity: clicks at 0.5 s spacing at 30 fps are ~15 frames apart.
      final frames = run();
      expect(frames, hasLength(4));
      for (var i = 1; i < frames.length; i++) {
        expect((frames[i] - frames[i - 1] - 15).abs(), lessThanOrEqualTo(1));
      }
    });
  });

  // A guard the synthetic generator stays honest: clicks really do create
  // energy (so a green onset test is not a vacuous pass over flat silence).
  test('the click track is not silent', () {
    final samples = _clickTrack(clickCount: 2, intervalSeconds: 0.5);
    final peak = samples.fold<double>(0, (acc, v) => math.max(acc, v.abs()));
    expect(peak, greaterThan(0.1));
  });
}
