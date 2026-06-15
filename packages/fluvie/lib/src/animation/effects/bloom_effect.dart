import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';

/// The effect behind `Animation.bloom`: a soft glow that bleeds light out of
/// the child's bright areas.
///
/// A pixel post-effect — it stacks a gaussian-blurred copy of the child
/// (via [ImageFiltered], a render-object filter) additively over the original
/// with [BlendMode.plus]. [ImageFiltered] and additive compositing both
/// capture cleanly through `RepaintBoundary.toImage`; no `BackdropFilter` is
/// used (it would read the wrong backdrop off-screen). The blur radius and
/// glow opacity are pure functions of [amount], so every pump is identical.
/// [amount] (clamped to `[0, 1]`) sets the glow's strength.
final class BloomEffect implements PixelAnimationEffect {
  /// Creates a bloom of the given [amount] strength (clamped to `[0, 1]`).
  const BloomEffect(double amount)
    : amount = amount < 0
          ? 0
          : amount > 1
          ? 1
          : amount;

  /// The glow strength in `[0, 1]`; `0` paints nothing.
  final double amount;

  @override
  Widget build(Widget child, double progress) {
    if (amount <= 0) return child;
    // Wider blur and more opacity with strength, both bounded so the glow
    // stays soft rather than washing the frame out.
    final sigma = 2 + amount * 8;
    final glowOpacity = 0.4 + amount * 0.5;
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        _AdditiveBlend(
          child: Opacity(
            opacity: glowOpacity,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  @override
  String toString() => 'BloomEffect(amount: $amount)';
}

/// Paints its child with [BlendMode.plus] so the blurred glow adds to the
/// original rather than covering it — a render-object filter, capture-safe.
class _AdditiveBlend extends SingleChildRenderObjectWidget {
  const _AdditiveBlend({required Widget child}) : super(child: child);

  @override
  _RenderAdditiveBlend createRenderObject(BuildContext context) => _RenderAdditiveBlend();
}

class _RenderAdditiveBlend extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.saveLayer(offset & size, Paint()..blendMode = BlendMode.plus);
    context.paintChild(child!, offset);
    context.canvas.restore();
  }
}
