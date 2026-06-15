import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';

/// Test stand-in for a Phase 9 pixel post-effect: draws a colored frame
/// around its child so ordering tests (§27.6) can find it in the tree.
///
/// Real pixel effects (grain, vignette, shaders) land in Phase 9; this fake
/// exists so the classification and pipeline-ordering contracts are pinned
/// from Phase 5 onward.
final class FakePixelEffect implements PixelAnimationEffect {
  /// Creates a fake pixel effect framing its child in [color].
  const FakePixelEffect({this.color = const Color(0xFFFF00FF)});

  /// The frame color; defaults to an unmistakable magenta.
  final Color color;

  @override
  Widget build(Widget child, double progress) => DecoratedBox(
    decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
    position: DecorationPosition.foreground,
    child: child,
  );
}
