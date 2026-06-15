import 'dart:typed_data';

import 'package:fluvie/src/core/audio/dsp/fft.dart';

/// The fixed analysis-frame constants behind the spectral-flux onset pipeline:
/// a 1024-sample Hann window advanced 512 samples per hop.
///
/// They are exposed so the onset-to-frame mapping (`onsetFramesAt`) and the
/// tests can convert a hop index back to a sample position without re-deriving
/// the geometry.
abstract final class SpectralFlux {
  /// The FFT window length in samples (a power of two for the radix-2 FFT).
  static const int defaultWindowSize = 1024;

  /// The samples advanced between consecutive analysis frames (50% overlap).
  static const int defaultHopSize = 512;
}

/// The positive spectral flux of [samples]: for each [windowSize]-sample frame
/// advanced by [hopSize], the sum over bins of the rise in magnitude since the
/// previous frame.
///
/// Each frame is Hann-windowed before its FFT (suppressing leakage), and only
/// *increases* in bin magnitude count toward the flux — a percussive onset
/// injects energy across many bins at once, so its frame spikes while steady
/// tones contribute nothing. The result is one flux value per frame, the signal
/// the onset peak-picker runs on. Pure and deterministic: identical [samples]
/// always produce an identical flux curve (the analyse-twice→identical proof).
///
/// A signal shorter than one window yields an empty list (no full frame to
/// analyse).
Float64List spectralFlux(
  Float64List samples, {
  int windowSize = SpectralFlux.defaultWindowSize,
  int hopSize = SpectralFlux.defaultHopSize,
}) {
  if (samples.length < windowSize) return Float64List(0);
  final frameCount = (samples.length - windowSize) ~/ hopSize + 1;
  final flux = Float64List(frameCount);
  Float64List? previous;
  final frame = Float64List(windowSize);
  for (var f = 0; f < frameCount; f++) {
    final start = f * hopSize;
    for (var i = 0; i < windowSize; i++) {
      frame[i] = samples[start + i];
    }
    final magnitudes = fftMagnitudes(applyHann(frame));
    flux[f] = previous == null ? 0 : _positiveFlux(magnitudes, previous);
    previous = Float64List.fromList(magnitudes);
  }
  return flux;
}

/// The sum of positive bin-by-bin rises from [previous] to [current].
double _positiveFlux(Float64List current, Float64List previous) {
  var sum = 0.0;
  for (var i = 0; i < current.length; i++) {
    final diff = current[i] - previous[i];
    if (diff > 0) sum += diff;
  }
  return sum;
}
