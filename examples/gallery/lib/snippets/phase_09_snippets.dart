// Compiled, tested snippets for the shaders-and-effects docs. They
// live here, not hand-typed in Markdown, so the documentation never drifts from
// a real API. Each `#docregion` flows into one fence via a
// `<!-- code-excerpt -->` marker.

// Animation.shader is @experimental by design; the shader
// snippet exists to document it, so the experimental-use warning is expected.
// The float snippet spells out the default amplitude so the doc reads as a full
// reference, which trips avoid_redundant_argument_values.
// ignore_for_file: avoid_redundant_argument_values, experimental_member_use
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// A caption with a seeded confetti burst — the same field every render.
// #docregion particles
Widget confettiCaption() =>
    const Text(
      'You did it',
      style: TextStyle(fontSize: 56, color: Color(0xFFFFFFFF)),
    ).animate([
      Animation.fadeIn(),
      Animation.particles(const Particles.confetti(seed: 'six-moments')),
    ]);
// #enddocregion particles

/// A logo distorted by the bundled ripple shader. The `.frag` loads once before
/// frame 0; experimental, and its fidelity varies by platform.
// #docregion shader
Widget rippleLogo() => const ColoredBox(
  color: Color(0xFF101820),
).animate([Animation.shader('packages/fluvie/shaders/ripple.frag')]);
// #enddocregion shader

/// A seeded float: a sine bob carrying a low-amplitude noise wobble drawn from
/// the same seeded source as particles, so it is organic but reproducible.
Animation seededFloat() =>
    // #docregion float-seed
    Animation.float(amplitude: 0.04, seed: 'leaf-7');
// #enddocregion float-seed

/// A text headline swept by a custom pixel effect — a horizontal scanline band
/// that travels with `progress`.
// #docregion custom-effect
Widget scanlineSweepText() => const Text(
  'Sweeping in',
  style: TextStyle(fontSize: 48, color: Color(0xFFFFFFFF)),
).animate([const Animation.custom(ScanlineSweep())]);

/// A custom pixel post-effect: implementing [PixelAnimationEffect] (not just
/// [AnimationEffect]) opts into the pixel class, so Fluvie applies it over the
/// transformed child, after every transform.
final class ScanlineSweep implements PixelAnimationEffect {
  const ScanlineSweep({this.band = 0.12});

  /// The band height, as a fraction of the child's height.
  final double band;

  @override
  Widget build(Widget child, double progress) => CustomPaint(
    foregroundPainter: _SweepPainter(progress: progress, band: band),
    child: child,
  );
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.progress, required this.band});

  final double progress;
  final double band;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height * band;
    final top = (size.height + height) * progress - height;
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, height),
      Paint()..color = const Color(0x33FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.band != band;
}

// #enddocregion custom-effect
