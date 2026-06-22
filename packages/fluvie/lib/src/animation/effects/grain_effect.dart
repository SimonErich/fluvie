import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/runtime/noise_scope.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';

/// The effect behind `Animation.grain`: a seeded monochrome film-grain
/// speckle painted over the child.
///
/// A pixel post-effect — it wraps the child in a `CustomPaint(foregroundPainter:)`
/// so the speckle composites over the already-rendered child with no backdrop
/// read and no `saveLayer`, which keeps it `RepaintBoundary.toImage`-safe for
/// capture. Every block's brightness is a pure function of its grid position
/// sampled from [NoiseSource], so two pumps at the same `progress` paint
/// the same pixels (so it caches and goldens). [amount] (clamped to
/// `[0, 1]`) scales the speckle's opacity; `progress` shifts the noise field
/// so an animated grain shimmers without ever using a clock or unseeded
/// `Random`.
final class GrainEffect implements PixelAnimationEffect {
  /// Creates film grain at the given [amount] strength (clamped to `[0, 1]`),
  /// sampling from [noise] (the const [ValueNoise] stub by default).
  const GrainEffect(double amount, {NoiseSource noise = const ValueNoise()})
    : amount = amount < 0
          ? 0
          : amount > 1
          ? 1
          : amount,
      _noise = noise; // ignore: prefer_initializing_formals — public arg `noise`, private field

  /// The grain strength in `[0, 1]`; `0` paints nothing.
  final double amount;

  final NoiseSource _noise;

  @override
  Widget build(Widget child, double progress) => Builder(
    builder: (context) => CustomPaint(
      // A mounted NoiseScope wins; otherwise the effect's own source (the const
      // ValueNoise() default), so a tree with no scope paints byte-identically.
      foregroundPainter: _GrainPainter(
        progress: progress,
        amount: amount,
        noise: NoiseScope.maybeOf(context) ?? _noise,
      ),
      child: child,
    ),
  );

  @override
  String toString() => 'GrainEffect(amount: $amount)';
}

/// Paints the monochrome speckle for one (progress, amount) pair.
final class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.progress, required this.amount, required this.noise});

  final double progress;
  final double amount;
  final NoiseSource noise;

  /// Each speckle covers a 2px block, fine enough to read as grain.
  static const double _block = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (amount <= 0) return;
    final columns = (size.width / _block).ceil();
    final rows = (size.height / _block).ceil();
    // Shift the sampled field by progress so an animated grain shimmers
    // deterministically (a frame-driven offset, never a clock).
    final shift = progress * 17.0;
    final paint = Paint();
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final value = noise.noise2(column + shift, row - shift);
        // Center the speckle around mid-gray so it both lightens and darkens.
        final luma = (value * 255).round().clamp(0, 255);
        final alpha = (value * amount * 200).round().clamp(0, 255);
        paint.color = Color.fromARGB(alpha, luma, luma, luma);
        canvas.drawRect(Rect.fromLTWH(column * _block, row * _block, _block, _block), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.amount != amount;
}
