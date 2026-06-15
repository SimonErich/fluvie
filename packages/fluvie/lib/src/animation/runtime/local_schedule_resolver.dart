import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/animation_plan_adapter.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/placement/effective_duration.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/plan/scene_plan.dart';
import 'package:fluvie/src/timing/resolver/composition_resolver.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Resolves one element's schedule without a composition around it — the
/// local fallback `MotionTarget` uses when no `ResolvedScheduleScope` is
/// mounted.
///
/// There is deliberately **no local trigger math**: the element becomes a
/// one-scene, one-element [CompositionPlan] (scene duration and fps from
/// [sceneScope]) and runs through [resolveCompositionDetailed] — the single
/// resolution code path — after which every span shifts by the scene's
/// absolute start frame. Placement, chaining, and spring-settle semantics
/// therefore hold by construction, frame for frame.
///
/// Locally workable triggers: `auto`, `at`, `previous`, `sceneStart`, and
/// `sceneEnd`. `after`/`whenStarts` reference anchors no local plan can
/// contain and `beat` has no grid, so the resolver throws a
/// [FluvieTimingError] for them — composition-level resolution (`Video`/`Scene`)
/// is where those triggers live.
///
/// [elementDefaults] merges over the package defaults; the
/// scene and video layers join the cascade through the injected
/// scope, never locally.
ElementSchedule resolveLocalSchedule({
  required List<Animation> animations,
  required TimeRange? window,
  required TimeScopeData sceneScope,
  Defaults? elementDefaults,
}) {
  final element = ElementPlan(
    ownerId: 'local element',
    window: window,
    animations: [for (final animation in animations) toAnimationPlan(animation)],
    defaults: elementDefaults,
  );
  final plan = CompositionPlan(
    fps: sceneScope.fps,
    scenes: [
      ScenePlan(
        id: 'local scene',
        duration: Time.frames(sceneScope.durationFrames),
        elements: [element],
      ),
    ],
  );
  final detailed = resolveCompositionDetailed(plan);
  final shift = sceneScope.startFrame;
  final resolvedWindow = detailed.windows[element]!;
  return ElementSchedule(
    window: ResolvedSpan(resolvedWindow.start + shift, resolvedWindow.end + shift),
    spans: List.unmodifiable([
      for (var i = 0; i < animations.length; i++)
        ResolvedSpan(detailed.spans[i]!.start + shift, detailed.spans[i]!.end + shift),
    ]),
    defaults: mergeDefaultsChain(element: elementDefaults),
  );
}
