import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/transition_strategy.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';

/// The [TransitionKind.zoom] blend: the incoming scene paints
/// plain below while the outgoing — on top, anchored at [Transition.into] —
/// scales from 1 to 2.0 and fades out, reading as a push *into* the cut.
final class ZoomStrategy implements TransitionStrategy {
  /// Const so [strategyFor] can hand out a singleton.
  const ZoomStrategy();

  /// The micro-default end scale, pinned by the `transition_zoom_mid` golden.
  static const double endScale = 2;

  @override
  List<Widget> compose({
    required Widget outgoing,
    required Widget incoming,
    required double easedProgress,
    required Transition spec,
  }) => [
    incoming,
    FadeBox(
      opacity: 1 - easedProgress,
      child: Transform.scale(
        scale: 1 + (endScale - 1) * easedProgress, // lerp(1, endScale, te)
        alignment: spec.into ?? Alignment.center,
        child: outgoing,
      ),
    ),
  ];
}
