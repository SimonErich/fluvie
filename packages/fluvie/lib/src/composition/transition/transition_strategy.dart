import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/fade_strategies.dart';
import 'package:fluvie/src/composition/transition/move_strategies.dart';
import 'package:fluvie/src/core/transition.dart';

/// One blend interface, many strategies: how a [Transition]
/// kind turns the outgoing/incoming scene pair into pixels for one frame.
///
/// The compositor stays uniform — it computes the eased progress, picks the
/// strategy via [strategyFor], and mounts whatever comes back; each strategy
/// owns its own stacking because paint order is kind-specific (zoom paints
/// the outgoing on top, every other kind the incoming).
// ignore: one_member_abstracts — strategy contract; a function type can't carry per-impl docs.
abstract interface class TransitionStrategy {
  /// Builds the blended pair for one frame, **in paint order** — the first
  /// widget paints below the second.
  ///
  /// [easedProgress] is the blend progress after [Transition.ease], in
  /// `(0, 1]`; [spec] supplies the kind-specific parameter (direction,
  /// anchor, or entry edge).
  List<Widget> compose({
    required Widget outgoing,
    required Widget incoming,
    required double easedProgress,
    required Transition spec,
  });
}

/// The strategy implementing [kind]'s blend.
///
/// Throws an [ArgumentError] for [TransitionKind.cut]: a cut has no blend
/// window — `stageAt` never reports blend roles across a cut boundary, so
/// the compositor never asks for its strategy.
TransitionStrategy strategyFor(TransitionKind kind) => switch (kind) {
  TransitionKind.cut => throw ArgumentError.value(
    kind,
    'kind',
    'a cut has no blend window and therefore no strategy',
  ),
  TransitionKind.crossFade => const CrossFadeStrategy(),
  TransitionKind.wipe => const WipeStrategy(),
  TransitionKind.zoom => const ZoomStrategy(),
  TransitionKind.slide => const SlideStrategy(),
};
