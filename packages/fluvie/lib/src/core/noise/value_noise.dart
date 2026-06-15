import 'package:fluvie/src/core/noise/noise_source.dart';

/// Hash-based value noise — the final [NoiseSource] algorithm.
///
/// Lattice values come from a pure integer hash of the integer coordinate
/// (FNV-style bit mixing over the low bits, no `dart:math` `Random`), and the
/// continuous lookups smoothstep-interpolate between them. Every result is a
/// deterministic function of its input, so two instances and two pumps always
/// agree — the determinism contract. All outputs lie in `[0, 1]`.
///
/// `const ValueNoise()` so effects default to it directly; an injected
/// `ctx.noise` provider can swap that default without changing the math, so
/// the goldens that ride this algorithm stay byte-identical.
final class ValueNoise implements NoiseSource {
  /// Creates the noise source; it carries no state, so it is `const`.
  const ValueNoise();

  /// The number of distinct lattice values a hash maps onto: a 24-bit range
  /// keeps the `[0, 1]` mapping exact under double arithmetic.
  static const int _range = 0xFFFFFF;

  @override
  double valueForSeed(String seed) => _hashToUnit(_hashCodeUnits(seed));

  @override
  double noise1(double x) {
    final x0 = _floor(x);
    final t = _smoothstep(x - x0);
    return _lerp(_lattice1(x0), _lattice1(x0 + 1), t);
  }

  @override
  double noise2(double x, double y) {
    final x0 = _floor(x);
    final y0 = _floor(y);
    final tx = _smoothstep(x - x0);
    final ty = _smoothstep(y - y0);
    final top = _lerp(_lattice2(x0, y0), _lattice2(x0 + 1, y0), tx);
    final bottom = _lerp(_lattice2(x0, y0 + 1), _lattice2(x0 + 1, y0 + 1), tx);
    return _lerp(top, bottom, ty);
  }

  /// The deterministic lattice value at integer coordinate [x], in `[0, 1]`.
  double _lattice1(int x) => _hashToUnit(_mix(0x9E3779B1, x));

  /// The deterministic lattice value at integer coordinate ([x], [y]).
  double _lattice2(int x, int y) => _hashToUnit(_mix(_mix(0x9E3779B1, x), y));

  /// FNV-1a-style single-step mix folding [value] into [hash], kept inside 32
  /// bits so the result is stable across platforms (no 64-bit reliance).
  int _mix(int hash, int value) {
    var h = (hash ^ (value & 0xFFFFFFFF)) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF; // the FNV-32 prime
    h ^= h >> 15;
    return h & 0xFFFFFFFF;
  }

  /// Folds every UTF-16 code unit of [seed] into one 32-bit hash.
  int _hashCodeUnits(String seed) {
    var h = 0x811C9DC5; // the FNV-32 offset basis
    for (final unit in seed.codeUnits) {
      h = _mix(h, unit);
    }
    return h;
  }

  /// Maps a 32-bit [hash] onto `[0, 1]` through its low 24 bits.
  double _hashToUnit(int hash) => (hash & _range) / _range;

  /// Hermite smoothstep `3t² − 2t³` on `[0, 1]`: flat slope at both ends, so
  /// the interpolation lands exactly on the lattice value at integer inputs.
  double _smoothstep(double t) => t * t * (3 - 2 * t);

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Floor toward negative infinity as an int (Dart's `~/` truncates toward
  /// zero, which would fold negative cells onto the wrong lattice point).
  int _floor(double x) {
    final truncated = x.toInt();
    return x < truncated ? truncated - 1 : truncated;
  }
}
