# Custom Effects

> **Build visual effect widgets**

Create custom visual effects that work within Fluvie's frame-based rendering system.

## Table of Contents

- [Overview](#overview)
- [Effect Widget Pattern](#effect-widget-pattern)
- [Particle Systems](#particle-systems)
- [Post-Processing Effects](#post-processing-effects)
- [Deterministic Randomness](#deterministic-randomness)
- [Examples](#examples)

---

## Overview

Custom effects in Fluvie must be:

1. **Deterministic**: Same frame number = same visual output
2. **Efficient**: Avoid expensive operations per frame
3. **Composable**: Work as overlay or child wrapper
4. **Mode-aware**: Support both preview and render modes

---

## Effect Widget Pattern

### Basic Structure

```dart
class CustomEffect extends StatelessWidget {
  final Widget child;
  final int startFrame;
  final int durationInFrames;

  const CustomEffect({
    super.key,
    required this.child,
    this.startFrame = 0,
    this.durationInFrames = 60,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, child) {
        // Calculate effect progress
        final localFrame = frame - startFrame;
        if (localFrame < 0 || localFrame >= durationInFrames) {
          return child!;  // Outside effect range
        }

        final progress = localFrame / durationInFrames;

        // Apply effect
        return _buildEffect(progress, child!);
      },
      child: child,
    );
  }

  Widget _buildEffect(double progress, Widget child) {
    // Override in subclass or implement here
    return child;
  }
}
```

### Using Layer Stack for Overlays

```dart
class GlowEffect extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double intensity;

  const GlowEffect({
    super.key,
    required this.child,
    this.glowColor = Colors.cyan,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, child) {
        // Pulsing glow
        final pulse = (sin(frame * 0.1) + 1) / 2 * intensity;

        return Stack(
          children: [
            // Glow layer (behind)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.5 * pulse),
                      blurRadius: 30 * pulse,
                      spreadRadius: 10 * pulse,
                    ),
                  ],
                ),
              ),
            ),
            // Original content
            child!,
          ],
        );
      },
      child: child,
    );
  }
}
```

---

## Particle Systems

### Basic Particle System

```dart
class Particle {
  final Offset position;
  final Offset velocity;
  final double size;
  final Color color;
  final double rotation;

  const Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.rotation,
  });

  Particle evolve(double dt) {
    return Particle(
      position: position + velocity * dt,
      velocity: velocity + Offset(0, 9.8 * dt),  // Gravity
      size: size * 0.99,  // Shrink
      color: color,
      rotation: rotation + dt,
    );
  }
}

class CustomParticleEffect extends StatelessWidget {
  final int particleCount;
  final int startFrame;
  final int durationInFrames;
  final int fps;

  const CustomParticleEffect({
    super.key,
    this.particleCount = 50,
    this.startFrame = 0,
    this.durationInFrames = 90,
    this.fps = 30,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final localFrame = frame - startFrame;
        if (localFrame < 0 || localFrame >= durationInFrames) {
          return const SizedBox.shrink();
        }

        // Generate particles deterministically
        final particles = _generateParticles(localFrame);

        return CustomPaint(
          painter: ParticlePainter(particles: particles),
          size: Size.infinite,
        );
      },
    );
  }

  List<Particle> _generateParticles(int frame) {
    final random = Random(42);  // Fixed seed for determinism
    final dt = 1.0 / fps;

    // Create initial particles
    var particles = List.generate(particleCount, (i) {
      return Particle(
        position: Offset(
          random.nextDouble() * 400 + 100,
          random.nextDouble() * 100 + 500,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 100,
          -random.nextDouble() * 200 - 100,
        ),
        size: random.nextDouble() * 10 + 5,
        color: Colors.primaries[random.nextInt(Colors.primaries.length)],
        rotation: random.nextDouble() * 2 * pi,
      );
    });

    // Evolve particles to current frame
    for (var f = 0; f < frame; f++) {
      particles = particles.map((p) => p.evolve(dt)).toList();
    }

    return particles;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()..color = particle.color;

      canvas.save();
      canvas.translate(particle.position.dx, particle.position.dy);
      canvas.rotate(particle.rotation);

      canvas.drawCircle(Offset.zero, particle.size, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}
```

### Optimized Particle System

For better performance, pre-calculate particle states:

```dart
class OptimizedParticleEffect extends StatefulWidget {
  final int particleCount;
  final int durationInFrames;

  const OptimizedParticleEffect({
    super.key,
    this.particleCount = 100,
    this.durationInFrames = 120,
  });

  @override
  State<OptimizedParticleEffect> createState() => _OptimizedParticleEffectState();
}

class _OptimizedParticleEffectState extends State<OptimizedParticleEffect> {
  late List<List<Particle>> _frameCache;

  @override
  void initState() {
    super.initState();
    _precomputeParticles();
  }

  void _precomputeParticles() {
    final random = Random(42);

    // Generate initial state
    var particles = List.generate(widget.particleCount, (i) {
      return Particle(/* ... */);
    });

    // Pre-compute all frames
    _frameCache = [particles];

    for (var f = 1; f < widget.durationInFrames; f++) {
      particles = particles.map((p) => p.evolve(1.0 / 30)).toList();
      _frameCache.add(particles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        if (frame < 0 || frame >= _frameCache.length) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: ParticlePainter(particles: _frameCache[frame]),
        );
      },
    );
  }
}
```

---

## Post-Processing Effects

### Color Matrix Effect

```dart
class ColorMatrixEffect extends StatelessWidget {
  final Widget child;
  final List<double> matrix;

  const ColorMatrixEffect({
    super.key,
    required this.child,
    required this.matrix,
  });

  // Predefined matrices
  static const grayscale = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const sepia = [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
  }
}
```

### Animated Color Grading

```dart
class AnimatedColorGrade extends StatelessWidget {
  final Widget child;
  final int startFrame;
  final int durationInFrames;
  final List<double> startMatrix;
  final List<double> endMatrix;

  const AnimatedColorGrade({
    super.key,
    required this.child,
    required this.startFrame,
    required this.durationInFrames,
    required this.startMatrix,
    required this.endMatrix,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, child) {
        final localFrame = frame - startFrame;
        final progress = (localFrame / durationInFrames).clamp(0.0, 1.0);

        // Interpolate color matrices
        final matrix = List.generate(
          20,
          (i) => lerpDouble(startMatrix[i], endMatrix[i], progress)!,
        );

        return ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: child!,
        );
      },
      child: child,
    );
  }
}
```

---

## Deterministic Randomness

### Using Frame-Seeded Random

```dart
class NoiseEffect extends StatelessWidget {
  final double intensity;

  const NoiseEffect({
    super.key,
    this.intensity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Frame-based seed ensures determinism
        final random = Random(frame * 12345);

        return CustomPaint(
          painter: NoisePainter(
            random: random,
            intensity: intensity,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class NoisePainter extends CustomPainter {
  final Random random;
  final double intensity;

  NoisePainter({required this.random, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Draw noise pixels
    for (var x = 0.0; x < size.width; x += 4) {
      for (var y = 0.0; y < size.height; y += 4) {
        final brightness = random.nextDouble();
        paint.color = Colors.white.withOpacity(brightness * intensity);
        canvas.drawRect(Rect.fromLTWH(x, y, 4, 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(NoisePainter oldDelegate) => true;
}
```

### Precomputed Noise Texture

```dart
class PrecomputedNoiseEffect extends StatefulWidget {
  final int frameCount;

  const PrecomputedNoiseEffect({
    super.key,
    this.frameCount = 30,  // Loop every 30 frames
  });

  @override
  State<PrecomputedNoiseEffect> createState() => _PrecomputedNoiseEffectState();
}

class _PrecomputedNoiseEffectState extends State<PrecomputedNoiseEffect> {
  late List<ui.Image> _noiseFrames;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _generateNoiseFrames();
  }

  Future<void> _generateNoiseFrames() async {
    final frames = <ui.Image>[];

    for (var i = 0; i < widget.frameCount; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final random = Random(i);

      // Draw noise
      for (var x = 0; x < 256; x++) {
        for (var y = 0; y < 256; y++) {
          final gray = random.nextInt(256);
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            Paint()..color = Color.fromARGB(50, gray, gray, gray),
          );
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(256, 256);
      frames.add(image);
    }

    setState(() {
      _noiseFrames = frames;
      _isLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    return TimeConsumer(
      builder: (context, frame, _) {
        final noiseFrame = frame % widget.frameCount;

        return RawImage(
          image: _noiseFrames[noiseFrame],
          fit: BoxFit.cover,
        );
      },
    );
  }
}
```

---

## Examples

### Scanline Effect

```dart
class ScanlineEffect extends StatelessWidget {
  final double lineSpacing;
  final double lineOpacity;

  const ScanlineEffect({
    super.key,
    this.lineSpacing = 4.0,
    this.lineOpacity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Animate scanline position
        final offset = (frame % lineSpacing.toInt()) / lineSpacing;

        return CustomPaint(
          painter: ScanlinePainter(
            spacing: lineSpacing,
            opacity: lineOpacity,
            offset: offset,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
```

### Glitch Effect

```dart
class GlitchEffect extends StatelessWidget {
  final Widget child;
  final double intensity;
  final int glitchSeed;

  const GlitchEffect({
    super.key,
    required this.child,
    this.intensity = 0.5,
    this.glitchSeed = 42,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, child) {
        final random = Random(frame * glitchSeed);

        // Only glitch some frames
        if (random.nextDouble() > intensity) {
          return child!;
        }

        // Random displacement
        final dx = (random.nextDouble() - 0.5) * 20;
        final dy = (random.nextDouble() - 0.5) * 10;

        return Stack(
          children: [
            // Red channel offset
            Positioned(
              left: dx,
              top: dy,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.red,
                  BlendMode.modulate,
                ),
                child: child!,
              ),
            ),
            // Blue channel offset
            Positioned(
              left: -dx,
              top: -dy,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.blue,
                  BlendMode.modulate,
                ),
                child: child!,
              ),
            ),
            // Original
            Opacity(opacity: 0.5, child: child!),
          ],
        );
      },
      child: child,
    );
  }
}
```

### Vignette Effect

```dart
class VignetteEffect extends StatelessWidget {
  final double intensity;
  final double radius;

  const VignetteEffect({
    super.key,
    this.intensity = 0.5,
    this.radius = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: VignettePainter(
        intensity: intensity,
        radius: radius,
      ),
      size: Size.infinite,
    );
  }
}

class VignettePainter extends CustomPainter {
  final double intensity;
  final double radius;

  VignettePainter({required this.intensity, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide / 2;

    final gradient = RadialGradient(
      center: Alignment.center,
      radius: radius,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(intensity),
      ],
      stops: const [0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: maxRadius),
      );

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(VignettePainter oldDelegate) =>
      intensity != oldDelegate.intensity || radius != oldDelegate.radius;
}
```

---

## Related

- [Particle Effects](../effects/particle-effect.md) - Built-in particles
- [Effect Overlay](../effects/effect-overlay.md) - Built-in overlays
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based widget
- [Custom Animations](custom-animations.md) - Animation system

