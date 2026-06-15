import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/core/particles/particle_palettes.dart';
import 'package:meta/meta.dart' show immutable;

/// The family of particle motion a [Particles] spec describes.
///
/// The kind picks how `ParticlesEffect` moves each particle: confetti tumbles
/// and falls, snow drifts down softly, sparkle twinkles roughly in place.
enum ParticleKind {
  /// Tumbling colored flakes that fall and spin — a celebratory burst.
  confetti,

  /// Soft flakes drifting gently downward — a calm snowfall.
  snow,

  /// Small points that twinkle in place with little fall — a glint accent.
  sparkle,
}

/// The declarative spec behind `Animation.particles`: pure data describing a
/// field of particles, never the particles themselves.
///
/// A spec carries everything `ParticlesEffect` needs to generate each
/// particle deterministically — the [kind], the [count], a [seed] string, a
/// color [palette], a size range ([minSize]/[maxSize]), and the motion trio
/// ([fallSpeed]/[drift]/[spinSpeed]). The effect turns these into per-particle
/// position, rotation, and color as a pure function of the particle index, the
/// scene progress, and `NoiseSource.valueForSeed("$seed-$i")`, so the same
/// spec always renders the identical field.
///
/// It holds only Flutter-math types ([Color]), so it lives in `core`. Two
/// specs are equal when every field matches, which keeps frame caching honest.
///
/// ```dart
/// Background.solid(Colors.black)
///     .animate([Animation.particles(Particles.confetti(seed: 'win'))]);
/// ```
@immutable
final class Particles {
  // Reason: const-ctor artifacts. particles_test pins the fields, equality, and
  // toString. The VM does not instrument the const literals themselves.
  // coverage:ignore-start
  /// The shared const constructor; the named factories pin each kind's
  /// defaults rather than exposing this directly.
  const Particles._({
    required this.kind,
    required this.count,
    required this.seed,
    required this.palette,
    required this.minSize,
    required this.maxSize,
    required this.fallSpeed,
    required this.drift,
    required this.spinSpeed,
  });

  /// A burst of tumbling colored confetti that falls and spins.
  ///
  /// Defaults: [count] `32`, [seed] `'confetti'`, a bright six-color
  /// [palette], `4`–`9` px flakes, and a brisk fall, sideways [drift], and
  /// fast [spinSpeed]. Pass any field to override one without restating the
  /// rest.
  const Particles.confetti({
    int count = 32,
    String seed = 'confetti',
    List<Color> palette = confettiPalette,
    double minSize = 4,
    double maxSize = 9,
    double fallSpeed = 0.9,
    double drift = 0.25,
    double spinSpeed = 2,
  }) : this._(
         kind: ParticleKind.confetti,
         count: count,
         seed: seed,
         palette: palette,
         minSize: minSize,
         maxSize: maxSize,
         fallSpeed: fallSpeed,
         drift: drift,
         spinSpeed: spinSpeed,
       );

  /// A soft snowfall of pale flakes drifting gently downward.
  ///
  /// Defaults: [count] `48`, [seed] `'snow'`, a near-white [palette], `2`–`5`
  /// px flakes, and a slow fall with light sideways [drift] and almost no
  /// spin.
  const Particles.snow({
    int count = 48,
    String seed = 'snow',
    List<Color> palette = snowPalette,
    double minSize = 2,
    double maxSize = 5,
    double fallSpeed = 0.4,
    double drift = 0.15,
    double spinSpeed = 0.2,
  }) : this._(
         kind: ParticleKind.snow,
         count: count,
         seed: seed,
         palette: palette,
         minSize: minSize,
         maxSize: maxSize,
         fallSpeed: fallSpeed,
         drift: drift,
         spinSpeed: spinSpeed,
       );

  /// A scatter of small points that twinkle roughly in place.
  ///
  /// Defaults: [count] `24`, [seed] `'sparkle'`, a warm-white [palette],
  /// `1.5`–`4` px points, and barely any fall (it glints rather than falls)
  /// with a brisk twinkle through [spinSpeed].
  const Particles.sparkle({
    int count = 24,
    String seed = 'sparkle',
    List<Color> palette = sparklePalette,
    double minSize = 1.5,
    double maxSize = 4,
    double fallSpeed = 0.08,
    double drift = 0.1,
    double spinSpeed = 1.5,
  }) : this._(
         kind: ParticleKind.sparkle,
         count: count,
         seed: seed,
         palette: palette,
         minSize: minSize,
         maxSize: maxSize,
         fallSpeed: fallSpeed,
         drift: drift,
         spinSpeed: spinSpeed,
       );
  // coverage:ignore-end

  /// Which motion family this field uses.
  final ParticleKind kind;

  /// How many particles to generate.
  final int count;

  /// The seed string behind every particle's placement; `"$seed-$i"` seeds
  /// particle `i`, so two fields with the same seed are byte-identical.
  final String seed;

  /// The colors particles cycle through, chosen per particle from its seed.
  final List<Color> palette;

  /// The smallest particle size, in logical pixels.
  final double minSize;

  /// The largest particle size, in logical pixels.
  final double maxSize;

  /// How far down a particle travels over one scene, as a fraction of the
  /// host's height (`1` is a full fall).
  final double fallSpeed;

  /// How far a particle wanders sideways, as a fraction of the host's width.
  final double drift;

  /// How fast a particle rotates, in turns per scene.
  final double spinSpeed;

  @override
  bool operator ==(Object other) =>
      other is Particles &&
      other.kind == kind &&
      other.count == count &&
      other.seed == seed &&
      listEquals(other.palette, palette) &&
      other.minSize == minSize &&
      other.maxSize == maxSize &&
      other.fallSpeed == fallSpeed &&
      other.drift == drift &&
      other.spinSpeed == spinSpeed;

  @override
  int get hashCode => Object.hash(
    kind,
    count,
    seed,
    Object.hashAll(palette),
    minSize,
    maxSize,
    fallSpeed,
    drift,
    spinSpeed,
  );

  @override
  String toString() => 'Particles.${kind.name}(count: $count, seed: $seed)';
}
