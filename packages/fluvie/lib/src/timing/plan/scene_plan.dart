/// @docImport 'package:fluvie/src/timing/plan/composition_plan.dart';
library;

import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:meta/meta.dart';

/// One scene in the plan model: a duration and the elements living inside it.
///
/// Scenes line up back-to-back inside a [CompositionPlan]; each one becomes a
/// child scope at the running offset of the scenes before it. The [duration]
/// must be absolute — a relative scene duration is circular and rejected at
/// resolution time.
@immutable
final class ScenePlan {
  /// Creates the plan for one scene; [id] and [duration] are required.
  const ScenePlan({
    required this.id,
    required this.duration,
    this.elements = const [],
    this.defaults,
  });

  /// A stable, human-readable identifier for diagnostics.
  final String id;

  /// How long the scene lasts; resolved against the root scope, so it must
  /// not contain a relative component.
  final Time duration;

  /// The animated elements declared in this scene, in declaration order.
  final List<ElementPlan> elements;

  /// Scene-level defaults, or `null` to inherit from the video.
  final Defaults? defaults;

  @override
  String toString() =>
      'ScenePlan($id, duration: $duration, elements: ${elements.length}, defaults: $defaults)';
}
