import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';

/// The effect behind `Animation.scanlines`: thin dark horizontal lines laid
/// over the child for a CRT/VHS look.
///
/// A pixel post-effect — it wraps the child in a `CustomPaint(foregroundPainter:)`
/// drawing one 1px dark line every [spacing] logical pixels. No `saveLayer`,
/// no backdrop read, so it captures cleanly. The line grid is a pure function
/// of the child's size, [spacing], and [opacity], so every pump is identical.
/// It takes no required parameter, matching the `scanlines()` preset.
final class ScanlinesEffect implements PixelAnimationEffect {
  /// Creates scanlines spaced [spacing] logical pixels apart at the given line
  /// [opacity] (clamped to `[0, 1]`).
  const ScanlinesEffect({this.spacing = 3, double opacity = 0.35})
    : assert(spacing > 0, 'scanline spacing must be > 0'),
      opacity = opacity < 0
          ? 0
          : opacity > 1
          ? 1
          : opacity;

  /// Logical pixels between consecutive lines; defaults to `3`.
  final double spacing;

  /// The darkness of each line in `[0, 1]`; defaults to `0.35`.
  final double opacity;

  @override
  Widget build(Widget child, double progress) => CustomPaint(
    foregroundPainter: _ScanlinesPainter(spacing: spacing, opacity: opacity, progress: progress),
    child: child,
  );

  @override
  String toString() => 'ScanlinesEffect(spacing: $spacing, opacity: $opacity)';
}

/// Paints the horizontal line grid for one (spacing, opacity) pair.
final class _ScanlinesPainter extends CustomPainter {
  const _ScanlinesPainter({
    required this.spacing,
    required this.opacity,
    required this.progress,
  });

  final double spacing;
  final double opacity;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final alpha = (opacity * 255).round().clamp(0, 255);
    final paint = Paint()..color = Color.fromARGB(alpha, 0, 0, 0);
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinesPainter oldDelegate) =>
      oldDelegate.spacing != spacing ||
      oldDelegate.opacity != opacity ||
      oldDelegate.progress != progress;
}
