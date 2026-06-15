/// @docImport 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
library;

import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/timing/placement/effective_duration.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/plan/scene_plan.dart';
import 'package:fluvie/src/timing/resolver/composition_resolver.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_registration.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';

/// What one composition resolution produced for the widget layer: the plan it
/// ran on, one [ElementSchedule] per registration token (keyed by token
/// identity), and the public timeline for the probe and `debugTimeline`.
typedef VideoPlanResult = ({
  CompositionPlan plan,
  Map<ElementRegistration, ElementSchedule> schedules,
  ResolvedTimeline timeline,
});

/// One scene's plan ingredients as the `Video` widget carries them.
typedef VideoSceneData = ({Time duration, Defaults? defaults});

/// Builds the [CompositionPlan] from the registrar's collected tokens, runs
/// [resolveCompositionDetailed] once, and assembles every element's
/// [ElementSchedule].
///
/// * One **fresh [ElementPlan] per token**, even for field-identical tokens
///   in different scenes — the resolver keys its maps by instance identity;
///   a token appearing in two scenes is an [ArgumentError].
/// * `ownerId` is `'s<sceneIndex>e<order>:<debugOwner>'`.
/// * The defaults cascade lands on every layer: [ScenePlan.defaults],
///   [CompositionPlan.defaults], and each schedule's fully merged chain.
///   [themeDefaults] is the `FluvieTheme.motion` layer — below [videoDefaults]
///   and above the package default; the shell reads it from
///   `context.fluvie.motion` so the `Video` surface stays unchanged.
/// * [defaultBeatGrid]/[trackBeatGrids] pass through so `Trigger.beat`
///   resolves at the composition level. `Video` does not thread a
///   `BeatGrid` into the plan, so `Trigger.beat` resolves only when a grid is
///   injected directly (tests, or the render shell).
/// * [boundaryTransitions] (one entry per scene boundary, `null` = cut) shift
///   the resolved scene offsets — an overlapping transition starts the
///   downstream scene early and shortens the total; the empty default is
///   all-cut and resolves byte-identically.
///
/// A pure function — identical input produces an identical result — so the
/// deferred second pass can never resolve differently across mounts. Plan
/// problems (cycles, dangling anchors, beatless grids) surface as the
/// resolver's [FluvieTimingError]s.
VideoPlanResult buildVideoPlan({
  required int fps,
  required List<VideoSceneData> scenes,
  required List<List<ElementRegistration>> registrationsByScene,
  Defaults? videoDefaults,
  Defaults? themeDefaults,
  List<Transition?> boundaryTransitions = const [],
  BeatGrid? defaultBeatGrid,
  Map<Anchor, BeatGrid> trackBeatGrids = const {},
}) {
  if (scenes.length != registrationsByScene.length) {
    throw ArgumentError(
      'buildVideoPlan needs one registration list per scene: got '
      '${registrationsByScene.length} lists for ${scenes.length} scenes.',
    );
  }
  final elementsByToken = <ElementRegistration, ElementPlan>{};
  final scenePlans = <ScenePlan>[];
  for (var s = 0; s < scenes.length; s++) {
    final registrations = registrationsByScene[s];
    final elements = <ElementPlan>[];
    for (var e = 0; e < registrations.length; e++) {
      final registration = registrations[e];
      if (elementsByToken.containsKey(registration)) {
        throw ArgumentError(
          'Registration token ${registration.debugOwner} appears in more than '
          'one scene — every element registers exactly one token.',
        );
      }
      // A fresh ElementPlan per token, never a reused instance.
      final element = ElementPlan(
        ownerId: 's${s}e$e:${registration.debugOwner}',
        anchor: registration.anchor,
        window: registration.window,
        animations: registration.animations,
        defaults: registration.defaults,
      );
      elements.add(element);
      elementsByToken[registration] = element;
    }
    scenePlans.add(
      ScenePlan(
        id: 'scenes[$s]',
        duration: scenes[s].duration,
        elements: elements,
        defaults: scenes[s].defaults,
      ),
    );
  }
  final plan = CompositionPlan(
    fps: fps,
    scenes: scenePlans,
    transitions: boundaryTransitions,
    defaults: videoDefaults,
    themeDefaults: themeDefaults,
    defaultBeatGrid: defaultBeatGrid,
    trackBeatGrids: trackBeatGrids,
  );
  final detailed = resolveCompositionDetailed(plan);

  // The registry walks scene → element → animation in declaration order, so
  // grouping its nodes by element keeps animationIndex order per element.
  final spansByElement = <ElementPlan, List<ResolvedSpan>>{};
  for (final node in detailed.registry.nodes) {
    (spansByElement[node.element] ??= []).add(detailed.spans[node.index]!);
  }
  final schedules = <ElementRegistration, ElementSchedule>{};
  for (var s = 0; s < scenes.length; s++) {
    for (final registration in registrationsByScene[s]) {
      final element = elementsByToken[registration]!;
      schedules[registration] = ElementSchedule(
        window: detailed.windows[element]!,
        spans: List.unmodifiable(spansByElement[element] ?? const <ResolvedSpan>[]),
        defaults: mergeDefaultsChain(
          element: registration.defaults,
          scene: scenes[s].defaults,
          video: videoDefaults,
          theme: themeDefaults,
        ),
      );
    }
  }
  return (plan: plan, schedules: schedules, timeline: detailed.timeline);
}
