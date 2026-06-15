import 'dart:math' as math;
import 'dart:typed_data';

/// The [size]-point symmetric Hann window: a raised cosine
/// `0.5·(1 − cos(2π·i / (size − 1)))`, zero at both endpoints and `1` in the
/// middle.
///
/// Windowing each FFT frame with a Hann taper before the transform suppresses
/// the spectral leakage a hard rectangular cut would smear across every bin, so
/// the band sums and the spectral-flux onset peaks stay sharp. Pure and
/// deterministic — the same [size] always yields the same window.
Float64List hannWindow(int size) {
  final window = Float64List(size);
  if (size == 1) {
    window[0] = 1;
    return window;
  }
  for (var i = 0; i < size; i++) {
    window[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (size - 1)));
  }
  return window;
}

/// Multiplies [signal] by its [hannWindow] pointwise, returning the tapered
/// frame the FFT consumes.
Float64List applyHann(Float64List signal) {
  final window = hannWindow(signal.length);
  final out = Float64List(signal.length);
  for (var i = 0; i < signal.length; i++) {
    out[i] = signal[i] * window[i];
  }
  return out;
}
