/// The seeded randomness source every deterministic effect reads from:
/// a pure function of its input, never a clock or an unseeded
/// `Random`. Identical input always yields the identical scalar, on every
/// machine and every pump, which is what makes grain, glitch, particles, and
/// seeded `float` reproducible.
///
/// Three lookups cover the consumers:
///
/// * [valueForSeed] turns a seed *string* into a stable scalar — the per-item
///   seed (`'$seed-$i'`) behind particle placement and slice jitter.
/// * [noise1] and [noise2] are continuous value noise over a 1-D or 2-D
///   coordinate — smooth enough that adjacent inputs read close, so grain
///   blocks and organic drift vary without hard steps.
///
/// All three return a value in `[0, 1]`.
///
/// The algorithm (`ValueNoise`) is **final**: the render context wires this
/// contract behind `ctx.noise` and the provider default, but does not
/// change the math, so every effect golden stays byte-identical.
abstract interface class NoiseSource {
  /// A stable scalar in `[0, 1]` hashed from [seed]; the same string always
  /// returns the same value, on every machine.
  double valueForSeed(String seed);

  /// Continuous 1-D value noise at [x], in `[0, 1]`; adjacent inputs read
  /// close (smoothstep-interpolated lattice values).
  double noise1(double x);

  /// Continuous 2-D value noise at ([x], [y]), in `[0, 1]`; adjacent inputs
  /// read close (smoothstep-interpolated lattice values).
  double noise2(double x, double y);
}
