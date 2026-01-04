import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';

/// Direction for particle movement.
enum ParticleDirection {
  /// Particles fall down.
  down,

  /// Particles rise up.
  up,

  /// Particles move to the right.
  right,

  /// Particles move to the left.
  left,

  /// Particles move in random directions.
  random,

  /// Particles radiate outward from center.
  radial,
}

/// Type of particle to render.
enum ParticleType {
  /// Simple circles.
  circle,

  /// Star shapes.
  star,

  /// Square shapes.
  square,

  /// Confetti rectangles with rotation.
  confetti,
}

/// A widget that renders animated particles.
///
/// [ParticleEffect] creates a particle system with configurable count, size,
/// speed, and direction. Particles are deterministic when [randomSeed] is set,
/// ensuring consistent rendering for video.
///
/// Example:
/// ```dart
/// ParticleEffect.sparkles(
///   count: 25,
///   color: Colors.yellow,
/// )
/// ```
class ParticleEffect extends StatelessWidget {
  /// Number of particles to render.
  final int count;

  /// Type of particles.
  final ParticleType type;

  /// Primary color for particles.
  final Color color;

  /// List of colors for multi-colored particles (e.g., confetti).
  final List<Color>? colors;

  /// Minimum particle size.
  final double minSize;

  /// Maximum particle size.
  final double maxSize;

  /// Minimum speed (pixels per frame).
  final double minSpeed;

  /// Maximum speed (pixels per frame).
  final double maxSpeed;

  /// Direction of particle movement.
  final ParticleDirection direction;

  /// Random seed for deterministic particle generation.
  final int randomSeed;

  /// Opacity of particles.
  final double opacity;

  /// Whether particles should fade out over time.
  final bool fadeOut;

  /// Creates a particle effect.
  const ParticleEffect({
    super.key,
    this.count = 25,
    this.type = ParticleType.circle,
    this.color = const Color(0xFFFFFFFF),
    this.colors,
    this.minSize = 2,
    this.maxSize = 6,
    this.minSpeed = 1,
    this.maxSpeed = 3,
    this.direction = ParticleDirection.down,
    this.randomSeed = 42,
    this.opacity = 1.0,
    this.fadeOut = false,
  });

  /// Creates a sparkle particle effect.
  const ParticleEffect.sparkles({
    super.key,
    this.count = 25,
    this.color = const Color(0xFFFFD700), // Gold
    this.opacity = 0.8,
    this.randomSeed = 42,
  })  : type = ParticleType.star,
        colors = null,
        minSize = 2,
        maxSize = 8,
        minSpeed = 0.5,
        maxSpeed = 2,
        direction = ParticleDirection.random,
        fadeOut = true;

  /// Creates a confetti particle effect.
  const ParticleEffect.confetti({
    super.key,
    this.count = 35,
    List<Color>? colors,
    this.opacity = 1.0,
    this.randomSeed = 42,
  })  : type = ParticleType.confetti,
        color = const Color(0xFFFFFFFF),
        colors = colors ??
            const [
              Color(0xFFFF6B6B),
              Color(0xFF4ECDC4),
              Color(0xFFFFE66D),
              Color(0xFF95E1D3),
              Color(0xFFF38181),
              Color(0xFFAA96DA),
            ],
        minSize = 6,
        maxSize = 12,
        minSpeed = 2,
        maxSpeed = 5,
        direction = ParticleDirection.down,
        fadeOut = false;

  /// Creates a snow particle effect.
  const ParticleEffect.snow({
    super.key,
    this.count = 50,
    this.color = const Color(0xFFFFFFFF),
    this.opacity = 0.8,
    this.randomSeed = 42,
  })  : type = ParticleType.circle,
        colors = null,
        minSize = 2,
        maxSize = 6,
        minSpeed = 1,
        maxSpeed = 2,
        direction = ParticleDirection.down,
        fadeOut = false;

  /// Creates a rising bubbles effect.
  const ParticleEffect.bubbles({
    super.key,
    this.count = 30,
    this.color = const Color(0xFFFFFFFF),
    this.opacity = 0.5,
    this.randomSeed = 42,
  })  : type = ParticleType.circle,
        colors = null,
        minSize = 4,
        maxSize = 12,
        minSpeed = 1,
        maxSpeed = 3,
        direction = ParticleDirection.up,
        fadeOut = false;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, progress) {
        final composition = VideoComposition.of(context);
        final size = MediaQuery.of(context).size;
        final width = composition?.width.toDouble() ?? size.width;
        final height = composition?.height.toDouble() ?? size.height;

        return CustomPaint(
          size: Size(width, height),
          painter: _ParticlePainter(
            count: count,
            type: type,
            color: color,
            colors: colors,
            minSize: minSize,
            maxSize: maxSize,
            minSpeed: minSpeed,
            maxSpeed: maxSpeed,
            direction: direction,
            randomSeed: randomSeed,
            opacity: opacity,
            fadeOut: fadeOut,
            frame: frame,
            width: width,
            height: height,
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final int count;
  final ParticleType type;
  final Color color;
  final List<Color>? colors;
  final double minSize;
  final double maxSize;
  final double minSpeed;
  final double maxSpeed;
  final ParticleDirection direction;
  final int randomSeed;
  final double opacity;
  final bool fadeOut;
  final int frame;
  final double width;
  final double height;

  late final List<_Particle> _particles;

  _ParticlePainter({
    required this.count,
    required this.type,
    required this.color,
    required this.colors,
    required this.minSize,
    required this.maxSize,
    required this.minSpeed,
    required this.maxSpeed,
    required this.direction,
    required this.randomSeed,
    required this.opacity,
    required this.fadeOut,
    required this.frame,
    required this.width,
    required this.height,
  }) {
    _particles = _generateParticles();
  }

  List<_Particle> _generateParticles() {
    final random = math.Random(randomSeed);
    final particles = <_Particle>[];

    for (int i = 0; i < count; i++) {
      final size = minSize + random.nextDouble() * (maxSize - minSize);
      final speed = minSpeed + random.nextDouble() * (maxSpeed - minSpeed);
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      final colorIndex = colors != null ? random.nextInt(colors!.length) : 0;
      final particleColor = colors?[colorIndex] ?? color;
      final rotation = random.nextDouble() * math.pi * 2;
      final rotationSpeed =
          (random.nextDouble() - 0.5) * 0.1; // Rotation per frame
      final phase = random.nextDouble(); // For staggered start

      // Calculate velocity based on direction
      double vx = 0;
      double vy = 0;
      switch (direction) {
        case ParticleDirection.down:
          vy = speed;
          vx = (random.nextDouble() - 0.5) * speed * 0.3;
          break;
        case ParticleDirection.up:
          vy = -speed;
          vx = (random.nextDouble() - 0.5) * speed * 0.3;
          break;
        case ParticleDirection.left:
          vx = -speed;
          vy = (random.nextDouble() - 0.5) * speed * 0.3;
          break;
        case ParticleDirection.right:
          vx = speed;
          vy = (random.nextDouble() - 0.5) * speed * 0.3;
          break;
        case ParticleDirection.random:
          final angle = random.nextDouble() * math.pi * 2;
          vx = math.cos(angle) * speed;
          vy = math.sin(angle) * speed;
          break;
        case ParticleDirection.radial:
          final angle = random.nextDouble() * math.pi * 2;
          vx = math.cos(angle) * speed;
          vy = math.sin(angle) * speed;
          break;
      }

      particles.add(
        _Particle(
          x: x,
          y: y,
          vx: vx,
          vy: vy,
          size: size,
          color: particleColor,
          rotation: rotation,
          rotationSpeed: rotationSpeed,
          phase: phase,
        ),
      );
    }

    return particles;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in _particles) {
      // Calculate position at current frame
      var x = particle.x + particle.vx * frame;
      var y = particle.y + particle.vy * frame;

      // Wrap around screen
      x = x % width;
      if (x < 0) x += width;
      y = y % height;
      if (y < 0) y += height;

      // Calculate opacity
      var particleOpacity = opacity;
      if (fadeOut) {
        // Fade based on position (for effects like sparkles)
        final lifeProgress =
            (particle.phase + frame / 100.0) % 1.0; // Cycle every 100 frames
        particleOpacity *= math.sin(lifeProgress * math.pi);
      }

      if (particleOpacity <= 0) continue;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: particleOpacity)
        ..style = PaintingStyle.fill;

      final rotation = particle.rotation + particle.rotationSpeed * frame;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      switch (type) {
        case ParticleType.circle:
          canvas.drawCircle(Offset.zero, particle.size / 2, paint);
          break;
        case ParticleType.square:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size,
            ),
            paint,
          );
          break;
        case ParticleType.star:
          _drawStar(canvas, paint, particle.size / 2, 5);
          break;
        case ParticleType.confetti:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size * 0.4,
            ),
            paint,
          );
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double radius, int points) {
    final path = Path();
    final innerRadius = radius * 0.4;

    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? radius : innerRadius;
      final x = r * math.cos(angle);
      final y = r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}

class _Particle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final Color color;
  final double rotation;
  final double rotationSpeed;
  final double phase;

  const _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.phase,
  });
}
