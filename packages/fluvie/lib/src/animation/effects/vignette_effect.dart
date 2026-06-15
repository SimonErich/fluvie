import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';

/// The effect behind `Animation.vignette`: a soft radial darkening from the
/// edges toward the center.
///
/// A pixel post-effect — it wraps the child in a `CustomPaint(foregroundPainter:)`
/// that paints one radial [Gradient] (transparent center, dark edges) over the
/// child. No `saveLayer`, no backdrop read, so it captures cleanly through
/// `RepaintBoundary.toImage`. The gradient is a pure function of the child's
/// size and [amount], so every pump paints identical pixels. [amount]
/// (clamped to `[0, 1]`) sets how dark the corners go.
final class VignetteEffect implements PixelAnimationEffect {
  /// Creates a vignette of the given [amount] strength (clamped to `[0, 1]`).
  const VignetteEffect(double amount)
    : amount = amount < 0
          ? 0
          : amount > 1
          ? 1
          : amount;

  /// The corner darkening strength in `[0, 1]`; `0` paints nothing.
  final double amount;

  @override
  Widget build(Widget child, double progress) => CustomPaint(
    foregroundPainter: _VignettePainter(amount: amount, progress: progress),
    child: child,
  );

  @override
  String toString() => 'VignetteEffect(amount: $amount)';
}

/// Paints the radial darkening for one [amount].
final class _VignettePainter extends CustomPainter {
  const _VignettePainter({required this.amount, required this.progress});

  final double amount;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (amount <= 0) return;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = center.distance;
    final edge = (amount * 0xCC).round().clamp(0, 255);
    final gradient = RadialGradient(
      colors: [const Color(0x00000000), Color.fromARGB(edge, 0, 0, 0)],
      // Keep the inner ~55% bright, then ramp to the darkened edge.
      stops: const [0.55, 1],
    );
    canvas.drawRect(
      rect,
      Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_VignettePainter oldDelegate) =>
      oldDelegate.amount != amount || oldDelegate.progress != progress;
}
