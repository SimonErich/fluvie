/// @docImport 'package:fluvie/src/animation/runtime/noise_scope.dart';
library;

import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:riverpod/riverpod.dart';

/// The seeded randomness source the render pipeline resolves: the
/// [ValueNoise] algorithm by default.
///
/// A `const ValueNoise()` is the default, every seeded effect (`grain`/`glitch`/
/// `particles`/`float`) and `ctx.noise` resolve the same source, and the goldens
/// stay byte-identical. Overridable with a fake in tests; the render shell
/// mounts the resolved source into a [NoiseScope] over the composition.
final noiseSourceProvider = Provider<NoiseSource>((ref) => const ValueNoise());
