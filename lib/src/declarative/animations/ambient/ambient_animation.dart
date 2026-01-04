import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../presentation/time_consumer.dart';
import '../../../presentation/video_composition.dart';

/// Base class for continuous ambient animations.
///
/// Ambient animations run continuously and are designed for looping.
/// They typically use noise/sine functions for organic motion and
/// are applied as widget wrappers rather than progress-based animations.
///
/// Example:
/// ```dart
/// FloatingVibe(
///   amplitude: 15,
///   frequency: 0.3,
///   child: MyWidget(),
/// )
/// ```
abstract class AmbientAnimation extends StatelessWidget {
  const AmbientAnimation({super.key});

  /// Whether this animation loops seamlessly.
  bool get seamlessLoop;
}

/// A Perlin noise-based floating animation for organic movement.
///
/// Creates natural-looking random-walk motion using layered
/// noise functions for smooth, unpredictable movement.
///
/// Example:
/// ```dart
/// FloatingVibe(
///   amplitude: 15,
///   frequency: 0.3,
///   seed: 42,
///   child: Icon(Icons.star, size: 48),
/// )
/// ```
class FloatingVibe extends AmbientAnimation {
  /// The child widget to animate.
  final Widget child;

  /// Maximum displacement amplitude in pixels.
  final double amplitude;

  /// Frequency of the floating motion (cycles per second).
  final double frequency;

  /// Random seed for reproducible motion.
  final int seed;

  /// Whether to include subtle rotation in the motion.
  final bool includeRotation;

  /// Maximum rotation amplitude in radians.
  final double rotationAmplitude;

  const FloatingVibe({
    super.key,
    required this.child,
    this.amplitude = 10,
    this.frequency = 0.4,
    this.seed = 42,
    this.includeRotation = false,
    this.rotationAmplitude = 0.05,
  });

  @override
  bool get seamlessLoop => true;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        // Use layered sine waves to approximate Perlin noise
        final t = frame / fps;
        final noise = _perlinNoise2D(t * frequency, seed);

        final xOffset = noise.dx * amplitude;
        final yOffset = noise.dy * amplitude;

        Widget result = Transform.translate(
          offset: Offset(xOffset, yOffset),
          child: child,
        );

        if (includeRotation) {
          final rotNoise = _perlinNoise1D(t * frequency * 0.7, seed + 100);
          result = Transform.rotate(
            angle: rotNoise * rotationAmplitude,
            child: result,
          );
        }

        return result;
      },
    );
  }

  /// Approximated 2D Perlin noise using layered sine waves.
  Offset _perlinNoise2D(double t, int seed) {
    final r = math.Random(seed);
    final phaseX1 = r.nextDouble() * 2 * math.pi;
    final phaseY1 = r.nextDouble() * 2 * math.pi;
    final phaseX2 = r.nextDouble() * 2 * math.pi;
    final phaseY2 = r.nextDouble() * 2 * math.pi;

    // Layer multiple frequencies for organic motion
    final x = math.sin(t * 2 * math.pi + phaseX1) * 0.6 +
        math.sin(t * 4.3 * math.pi + phaseX2) * 0.4;
    final y = math.sin(t * 2.1 * math.pi + phaseY1) * 0.6 +
        math.sin(t * 3.7 * math.pi + phaseY2) * 0.4;

    return Offset(x, y);
  }

  /// Approximated 1D Perlin noise.
  double _perlinNoise1D(double t, int seed) {
    final r = math.Random(seed);
    final phase1 = r.nextDouble() * 2 * math.pi;
    final phase2 = r.nextDouble() * 2 * math.pi;

    return math.sin(t * 2 * math.pi + phase1) * 0.7 +
        math.sin(t * 5.1 * math.pi + phase2) * 0.3;
  }
}

/// Orbital rotation animation where elements rotate around a center point.
///
/// Example:
/// ```dart
/// OrbitalRotation(
///   radius: 100,
///   speed: 0.5, // rotations per second
///   children: [
///     Icon(Icons.star),
///     Icon(Icons.star),
///     Icon(Icons.star),
///   ],
/// )
/// ```
class OrbitalRotation extends AmbientAnimation {
  /// Children to orbit around the center.
  final List<Widget> children;

  /// Radius of the orbit in pixels.
  final double radius;

  /// Rotations per second.
  final double speed;

  /// Center alignment of the orbit.
  final Alignment center;

  /// Whether to rotate counter-clockwise.
  final bool counterClockwise;

  /// Starting angle in radians.
  final double startAngle;

  /// Whether each child should self-rotate as it orbits.
  final bool selfRotate;

  const OrbitalRotation({
    super.key,
    required this.children,
    this.radius = 100,
    this.speed = 0.5,
    this.center = Alignment.center,
    this.counterClockwise = false,
    this.startAngle = 0,
    this.selfRotate = false,
  });

  @override
  bool get seamlessLoop => true;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        final time = frame / fps;
        final baseAngle = startAngle + (time * speed * 2 * math.pi);
        final direction = counterClockwise ? -1.0 : 1.0;

        return Stack(
          alignment: center,
          clipBehavior: Clip.none,
          children: List.generate(children.length, (index) {
            final angleOffset = (index / children.length) * 2 * math.pi;
            final angle = (baseAngle + angleOffset) * direction;

            final x = radius * math.cos(angle);
            final y = radius * math.sin(angle);

            Widget child = children[index];

            if (selfRotate) {
              child = Transform.rotate(angle: angle, child: child);
            }

            return Transform.translate(offset: Offset(x, y), child: child);
          }),
        );
      },
    );
  }
}

/// A pulsing scale animation that can sync to audio BPM.
///
/// Example:
/// ```dart
/// PulseSync(
///   minScale: 0.95,
///   maxScale: 1.05,
///   bpm: 120,
///   child: Container(
///     width: 100,
///     height: 100,
///     color: Colors.red,
///   ),
/// )
/// ```
class PulseSync extends AmbientAnimation {
  /// The child widget to animate.
  final Widget child;

  /// Minimum scale during pulse.
  final double minScale;

  /// Maximum scale during pulse.
  final double maxScale;

  /// Beats per minute. If null, defaults to 120.
  /// In the future, this could be auto-detected from audio.
  final int? bpm;

  /// Curve to apply to the pulse motion.
  final Curve pulseCurve;

  /// Alignment for the scale transform.
  final Alignment alignment;

  const PulseSync({
    super.key,
    required this.child,
    this.minScale = 0.95,
    this.maxScale = 1.05,
    this.bpm,
    this.pulseCurve = Curves.easeInOut,
    this.alignment = Alignment.center,
  });

  @override
  bool get seamlessLoop => true;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        // Calculate beat timing
        final effectiveBpm = bpm ?? 120;
        final beatsPerSecond = effectiveBpm / 60.0;
        final framesPerBeat = fps / beatsPerSecond;

        // Calculate position within current beat (0.0 to 1.0)
        final beatProgress = (frame % framesPerBeat) / framesPerBeat;

        // Apply curve for more musical feel
        final curvedProgress = pulseCurve.transform(beatProgress);

        // Scale oscillates: max at beat start, min at beat middle
        final scale = maxScale -
            (maxScale - minScale) *
                (1 - math.cos(curvedProgress * 2 * math.pi)) /
                2;

        return Transform.scale(
          scale: scale,
          alignment: alignment,
          child: child,
        );
      },
    );
  }
}

/// A breathing animation for subtle scale oscillation.
///
/// Similar to [PulseSync] but designed for continuous, gentle motion
/// rather than beat-synced pulses.
class BreathingAnimation extends AmbientAnimation {
  /// The child widget to animate.
  final Widget child;

  /// Minimum scale during the breath cycle.
  final double minScale;

  /// Maximum scale during the breath cycle.
  final double maxScale;

  /// Duration of one complete breath cycle in seconds.
  final double cycleDuration;

  /// Alignment for the scale transform.
  final Alignment alignment;

  const BreathingAnimation({
    super.key,
    required this.child,
    this.minScale = 0.98,
    this.maxScale = 1.02,
    this.cycleDuration = 3.0,
    this.alignment = Alignment.center,
  });

  @override
  bool get seamlessLoop => true;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        final time = frame / fps;
        final cycleProgress = (time / cycleDuration) % 1.0;

        // Smooth sine wave for natural breathing motion
        final scale = minScale +
            (maxScale - minScale) *
                (1 + math.sin(cycleProgress * 2 * math.pi)) /
                2;

        return Transform.scale(
          scale: scale,
          alignment: alignment,
          child: child,
        );
      },
    );
  }
}

/// A wobble animation for rotational oscillation.
///
/// Creates a gentle back-and-forth rotation effect.
class WobbleAnimation extends AmbientAnimation {
  /// The child widget to animate.
  final Widget child;

  /// Maximum rotation angle in degrees.
  final double maxAngle;

  /// Speed of the wobble (cycles per second).
  final double speed;

  /// Random seed for slight variation.
  final int seed;

  /// Alignment for the rotation transform.
  final Alignment alignment;

  const WobbleAnimation({
    super.key,
    required this.child,
    this.maxAngle = 3.0,
    this.speed = 0.5,
    this.seed = 42,
    this.alignment = Alignment.center,
  });

  @override
  bool get seamlessLoop => true;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        final time = frame / fps;
        final r = math.Random(seed);
        final phase = r.nextDouble() * 2 * math.pi;

        final angle = maxAngle * math.sin(time * speed * 2 * math.pi + phase);
        final radians = angle * math.pi / 180;

        return Transform.rotate(
          angle: radians,
          alignment: alignment,
          child: child,
        );
      },
    );
  }
}
