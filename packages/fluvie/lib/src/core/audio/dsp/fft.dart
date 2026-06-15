import 'dart:math' as math;
import 'dart:typed_data';

export 'package:fluvie/src/core/audio/dsp/band_energy.dart';
export 'package:fluvie/src/core/audio/dsp/hann.dart';

/// A complex spectrum as two parallel arrays: the real (`re`) and imaginary
/// (`im`) parts of each of the `N` frequency bins.
typedef ComplexSpectrum = ({Float64List re, Float64List im});

/// The radix-2 Cooley-Tukey forward FFT of real [input].
///
/// In-house on purpose: a dependency would penalize pana, the algorithm is
/// small, and owning it lets the analyse-twice→identical determinism proof rest
/// on code Fluvie controls. The input length must be a power of two (the
/// spectral-flux pipeline always windows to 1024); a non-power-of-two length is
/// an [ArgumentError]. Returns the full `N`-bin complex spectrum.
ComplexSpectrum fft(Float64List input) {
  final n = input.length;
  if (n == 0 || (n & (n - 1)) != 0) {
    throw ArgumentError.value(n, 'input.length', 'must be a power of two and > 0');
  }
  final re = Float64List.fromList(input);
  final im = Float64List(n);
  _bitReverse(re, im);
  _butterflies(re, im);
  return (re: re, im: im);
}

/// The single-sided magnitude spectrum of real [input]: the `N/2 + 1` bins from
/// DC up to Nyquist, each the modulus `sqrt(re² + im²)` of the [fft] output.
///
/// This is what the band-energy and spectral-flux passes read — the phase is
/// discarded because onset detection and band sums need magnitude only.
Float64List fftMagnitudes(Float64List input) {
  final (:re, :im) = fft(input);
  final half = input.length ~/ 2;
  final magnitudes = Float64List(half + 1);
  for (var i = 0; i <= half; i++) {
    magnitudes[i] = math.sqrt(re[i] * re[i] + im[i] * im[i]);
  }
  return magnitudes;
}

/// Reorders [re]/[im] in place into bit-reversed index order — the in-place
/// prelude every Cooley-Tukey FFT runs before its butterfly passes.
void _bitReverse(Float64List re, Float64List im) {
  final n = re.length;
  var j = 0;
  for (var i = 1; i < n; i++) {
    var bit = n >> 1;
    for (; (j & bit) != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
}

/// Runs the in-place butterfly passes over the bit-reversed [re]/[im], doubling
/// the transform length each pass until the whole array is one DFT.
void _butterflies(Float64List re, Float64List im) {
  final n = re.length;
  for (var len = 2; len <= n; len <<= 1) {
    final angle = -2 * math.pi / len;
    final wRe = math.cos(angle);
    final wIm = math.sin(angle);
    for (var start = 0; start < n; start += len) {
      var curRe = 1.0;
      var curIm = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final i = start + k;
        final j = i + len ~/ 2;
        final tRe = curRe * re[j] - curIm * im[j];
        final tIm = curRe * im[j] + curIm * re[j];
        re[j] = re[i] - tRe;
        im[j] = im[i] - tIm;
        re[i] += tRe;
        im[i] += tIm;
        final nextRe = curRe * wRe - curIm * wIm;
        curIm = curRe * wIm + curIm * wRe;
        curRe = nextRe;
      }
    }
  }
}
