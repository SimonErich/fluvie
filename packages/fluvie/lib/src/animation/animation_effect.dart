import 'package:flutter/widgets.dart' show Widget;

/// The contract every visual animation reduces to: a pure function of
/// `progress` applied to a child widget.
///
/// Fluvie owns timing, curves, and frames — an effect only ever sees the
/// already-shaped [build] `progress` (`0 → 1`, springs may overshoot) and
/// must be deterministic: the same child and progress always produce the
/// same widget tree.
///
/// ```dart
/// final class Shear implements AnimationEffect {
///   const Shear({this.maxSkew = 0.3});
///   final double maxSkew;
///   @override
///   Widget build(Widget child, double progress) =>
///       Transform(transform: Matrix4.skewX((1 - progress) * maxSkew), child: child);
/// }
/// ```
// One member by design: the custom-effect contract is pinned to this exact
// shape so user effects write `implements AnimationEffect` verbatim.
// ignore: one_member_abstracts
abstract interface class AnimationEffect {
  /// Wraps [child] with this effect's visual state at [progress].
  Widget build(Widget child, double progress);
}
