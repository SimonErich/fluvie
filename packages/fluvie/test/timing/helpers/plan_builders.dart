import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/plan/scene_plan.dart';

/// Terse [AnimationPlan] factory for tests; every parameter mirrors the
/// production default.
AnimationPlan anim({
  AnimationPhase phase = AnimationPhase.enter,
  Timing? timing,
  Time delay = Time.zero,
  Trigger at = Trigger.auto,
  Stagger? stagger,
  Repeat? repeat,
  String? label,
}) => AnimationPlan(
  phase: phase,
  timing: timing,
  delay: delay,
  at: at,
  stagger: stagger,
  repeat: repeat,
  label: label,
);

/// Terse [ElementPlan] factory for tests.
ElementPlan element(
  String ownerId, {
  Anchor? anchor,
  TimeRange? window,
  List<AnimationPlan> animations = const [],
  Defaults? defaults,
}) => ElementPlan(
  ownerId: ownerId,
  anchor: anchor,
  window: window,
  animations: animations,
  defaults: defaults,
);

/// Terse [ScenePlan] factory for tests.
ScenePlan scene(
  String id, {
  required Time duration,
  List<ElementPlan> elements = const [],
  Defaults? defaults,
}) => ScenePlan(id: id, duration: duration, elements: elements, defaults: defaults);

/// Terse [CompositionPlan] factory for tests.
CompositionPlan composition({
  int fps = 30,
  List<ScenePlan> scenes = const [],
  List<Transition?> transitions = const [],
  Defaults? defaults,
  BeatGrid? defaultBeatGrid,
  Map<Anchor, BeatGrid> trackBeatGrids = const {},
}) => CompositionPlan(
  fps: fps,
  scenes: scenes,
  transitions: transitions,
  defaults: defaults,
  defaultBeatGrid: defaultBeatGrid,
  trackBeatGrids: trackBeatGrids,
);
