/// @docImport 'package:fluvie/src/timing/schedule/composition_registrar.dart';
library;

import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';

/// One element's registration token for a [CompositionRegistrar]: everything
/// the composition-level plan builder needs from a single `.animate()` call, in
/// plan-level types only — no widgets, no `Animation`s.
///
/// A token is **identity-compared, deliberately**: it has no value equality,
/// because the registering element holds its token for its whole lifetime and
/// the registrar keys schedules by that exact object. Two field-identical
/// tokens are two distinct elements (the same way two `Anchor('x')` are two
/// distinct handles), which is what lets visually identical elements in
/// different scenes resolve to distinct per-scene windows.
final class ElementRegistration {
  /// Creates a registration token; only [debugOwner] is required.
  ElementRegistration({
    required this.debugOwner,
    this.anchor,
    this.window,
    this.animations = const [],
    this.defaults,
  });

  /// A human-readable owner name for diagnostics — the anchor's debug name
  /// when the element has one, else its child's runtime type.
  final String debugOwner;

  /// The handle other elements' triggers reference, or `null` when nothing
  /// chains off this element. Compared by identity.
  final Anchor? anchor;

  /// The element's alive-window within its scene — explicit, or inherited
  /// from an enclosing windowed element — or `null` for the whole scene.
  final TimeRange? window;

  /// The element's animations as pure plan data, in declaration order.
  final List<AnimationPlan> animations;

  /// Element-level defaults from `.animate(defaults:)`, or `null` to inherit
  /// the scene/video cascade.
  final Defaults? defaults;

  @override
  String toString() =>
      'ElementRegistration($debugOwner, anchor: $anchor, window: $window, '
      'animations: ${animations.length}, defaults: $defaults)';
}
