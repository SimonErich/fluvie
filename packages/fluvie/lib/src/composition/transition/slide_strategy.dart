import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/transition_strategy.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/transition.dart';

/// The [TransitionKind.slide] blend: a push. The incoming
/// scene translates in from the [Transition.from] edge while the outgoing
/// translates off toward the opposite edge, both as fractions of the canvas
/// via the shared [Edge.dx]/[Edge.dy] convention.
final class SlideStrategy implements TransitionStrategy {
  /// Const so [strategyFor] can hand out a singleton.
  const SlideStrategy();

  @override
  List<Widget> compose({
    required Widget outgoing,
    required Widget incoming,
    required double easedProgress,
    required Transition spec,
  }) {
    final from = spec.from ?? Edge.right;
    final entry = Offset(from.dx, from.dy);
    return [
      FractionalTranslation(translation: -entry * easedProgress, child: outgoing),
      FractionalTranslation(translation: entry * (1 - easedProgress), child: incoming),
    ];
  }
}
