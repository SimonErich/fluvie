import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/transition_strategy.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';

/// The [TransitionKind.crossFade] blend: the outgoing scene
/// paints plain below while the incoming fades in above through a single
/// [FadeBox] — opaque-over-opaque equals a classic dissolve with no
/// dip-to-background artifact.
final class CrossFadeStrategy implements TransitionStrategy {
  /// Const so [strategyFor] can hand out a singleton.
  const CrossFadeStrategy();

  @override
  List<Widget> compose({
    required Widget outgoing,
    required Widget incoming,
    required double easedProgress,
    required Transition spec,
  }) => [outgoing, FadeBox(opacity: easedProgress, child: incoming)];
}
