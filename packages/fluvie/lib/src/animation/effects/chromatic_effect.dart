import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';

/// The effect behind `Animation.chromatic`: a red/blue channel split that
/// fringes edges like a cheap lens.
///
/// A pixel post-effect — it renders the child three times, the red copy
/// shifted [px] logical pixels one way and the blue copy [px] the other, the
/// green copy centered, and adds the three with [BlendMode.plus]. Additive
/// compositing over the child is a render-object filter, capture-safe through
/// `RepaintBoundary.toImage` (no `BackdropFilter`, which would read the wrong
/// backdrop off-screen). The geometry is a pure function of [px], so every
/// pump paints identical pixels.
final class ChromaticEffect implements PixelAnimationEffect {
  /// Creates an aberration splitting the channels by [px] logical pixels.
  const ChromaticEffect(this.px);

  /// The channel offset in logical pixels.
  final double px;

  @override
  Widget build(Widget child, double progress) => _ChannelSplit(px: px, child: child);

  @override
  String toString() => 'ChromaticEffect(px: $px)';
}

/// Stacks the three channel-isolated, offset copies, each blended additively.
class _ChannelSplit extends StatelessWidget {
  const _ChannelSplit({required this.px, required this.child});

  final double px;
  final Widget child;

  /// Zeroes every channel except the one [keep] selects (0 = red, 1 = green,
  /// 2 = blue), leaving alpha intact.
  static List<double> _channelMatrix(int keep) {
    final r = keep == 0 ? 1.0 : 0.0;
    final g = keep == 1 ? 1.0 : 0.0;
    final b = keep == 2 ? 1.0 : 0.0;
    return <double>[
      r, 0, 0, 0, 0, //
      0, g, 0, 0, 0, //
      0, 0, b, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  Widget _channel(int keep, double dx) => Transform.translate(
    offset: Offset(dx, 0),
    child: ColorFiltered(colorFilter: ColorFilter.matrix(_channelMatrix(keep)), child: child),
  );

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      _PlusBlend(child: _channel(0, -px)),
      _PlusBlend(child: _channel(1, 0)),
      _PlusBlend(child: _channel(2, px)),
    ],
  );
}

/// Paints its child with [BlendMode.plus] so the stacked channel copies add
/// rather than overwrite — a render-object filter, capture-safe.
class _PlusBlend extends SingleChildRenderObjectWidget {
  const _PlusBlend({required Widget child}) : super(child: child);

  @override
  _RenderPlusBlend createRenderObject(BuildContext context) => _RenderPlusBlend();
}

class _RenderPlusBlend extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.saveLayer(offset & size, Paint()..blendMode = BlendMode.plus);
    context.paintChild(child!, offset);
    context.canvas.restore();
  }
}
