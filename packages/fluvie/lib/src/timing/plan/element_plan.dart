/// @docImport 'package:fluvie/src/timing/plan/scene_plan.dart';
library;

import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:meta/meta.dart';

/// One animated element in the plan model: what a single `.animate()` call
/// declares, stripped of the widget itself.
///
/// An element lives inside a [ScenePlan]; its [window] (or, absent one, the
/// whole scene) is the span its animations are placed within.
@immutable
final class ElementPlan {
  /// Creates the plan for one element; only [ownerId] is required.
  const ElementPlan({
    required this.ownerId,
    this.anchor,
    this.window,
    this.animations = const [],
    this.defaults,
  });

  /// A stable, human-readable identifier for diagnostics and timeline rows
  /// (for example, the widget's debug label).
  final String ownerId;

  /// The handle other elements' triggers reference, or `null` when nothing
  /// chains off this element. Compared by identity.
  final Anchor? anchor;

  /// The element's alive-window within its scene, or `null` for the whole
  /// scene.
  final TimeRange? window;

  /// The animations declared on this element, in declaration order.
  final List<AnimationPlan> animations;

  /// Element-level defaults from `.animate(defaults:)`, or `null` to inherit
  /// from the scene.
  final Defaults? defaults;

  @override
  String toString() =>
      'ElementPlan($ownerId, anchor: $anchor, window: $window, '
      'animations: ${animations.length}, defaults: $defaults)';
}
