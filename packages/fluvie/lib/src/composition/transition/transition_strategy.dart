import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/cross_fade_strategy.dart';
import 'package:fluvie/src/composition/transition/slide_strategy.dart';
import 'package:fluvie/src/composition/transition/wipe_strategy.dart';
import 'package:fluvie/src/composition/transition/zoom_strategy.dart';
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
TransitionStrategy strategyFor(Object kind) {
  final name = kind is TransitionKind ? kind.name : kind;
  if (name == 'cut') {
    throw ArgumentError.value(kind, 'kind', 'a cut has no blend window and therefore no strategy');
  }
  final strategy = _strategies[name];
  if (strategy == null) {
    throw ArgumentError.value(kind, 'kind', 'No transition strategy is registered');
  }
  return strategy;
}

const _builtIns = {'crossFade', 'wipe', 'zoom', 'slide'};
final Map<String, TransitionStrategy> _strategies = {
  'crossFade': const CrossFadeStrategy(),
  'wipe': const WipeStrategy(),
  'zoom': const ZoomStrategy(),
  'slide': const SlideStrategy(),
};

/// Whether a kind can be decoded and composed by this runtime.
bool hasTransitionStrategy(String kind) => _strategies.containsKey(kind);

/// Registers an out-of-tree strategy under a unique kind name. Built-ins and
/// `cut` are reserved. Registration is explicit and never changes saved data.
void registerTransitionStrategy(String kind, TransitionStrategy strategy) {
  if (kind.trim().isEmpty || kind == 'cut' || kind == 'custom' || _strategies.containsKey(kind)) {
    throw ArgumentError.value(kind, 'kind', 'Choose a non-empty, unregistered transition kind');
  }
  _strategies[kind] = strategy;
}

/// Removes a custom strategy, for plugin unload or an isolated test. Built-ins
/// cannot be removed because existing documents rely on them.
void unregisterTransitionStrategy(String kind) {
  if (_builtIns.contains(kind) || kind == 'cut') {
    throw ArgumentError.value(kind, 'kind', 'Built-in strategies cannot be removed');
  }
  _strategies.remove(kind);
}
