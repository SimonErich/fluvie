import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';

import 'plan_builders.dart';

/// The API_SPEC §26 multi-scene clip as a Phase 3 plan, shared by the
/// `resolveComposition` acceptance test and the `debugTimeline` golden.
///
/// Approximations (the plan model has no widgets):
///
/// * Counters, captions, and pixel effects are plain ownerIds.
/// * §26 writes `Trigger.previous` on the subtitle's slideFadeIn, chaining off
///   the sibling title's pop; under D6 `previous` chains within one element,
///   so pop and slideFadeIn live on a single `title` element here.
/// * The hero-shared logo is an anchored, animation-less element (hero
///   morphing is Phase 7); the audio track and its beat grid play no part in
///   the resolved schedule.
///
/// Expected schedule @30fps (default spring settles in 36 frames; the package
/// default duration is `min(0.2 × window, 0.8s)`):
///
/// | owner    | label     | phase  | span     |
/// |----------|-----------|--------|----------|
/// | title    | pop       | enter  | 0..36    |
/// | title    | slideFadeIn | enter  | 39..57   |
/// | counter  | count     | enter  | 90..150  |
/// | stats-fx | grain     | during | 90..210  |
/// | stats-fx | vignette  | during | 90..210  |
/// | caption  | fadeIn    | enter  | 135..159 |
/// | outro    | blurIn    | enter  | 210..228 |
/// | outro    | float     | during | 210..300 |
/// | outro    | fadeOut   | exit   | 282..300 |
CompositionPlan workedExample() {
  final logo = Anchor('logo');
  return composition(
    defaults: const Defaults(ease: Ease.smooth),
    scenes: [
      scene(
        'intro',
        duration: 3.seconds,
        elements: [
          element('logo', anchor: logo),
          element(
            'title',
            animations: [
              anim(label: 'pop', timing: const Spring()),
              anim(label: 'slideFadeIn', at: Trigger.previous, delay: 0.1.seconds),
            ],
          ),
        ],
      ),
      scene(
        'stats',
        duration: 4.seconds,
        elements: [
          element(
            'counter',
            animations: [anim(label: 'count', timing: Tween(2.seconds))],
          ),
          element(
            'caption',
            animations: [anim(label: 'fadeIn', delay: 1.5.seconds)],
          ),
          element(
            'stats-fx',
            animations: [
              anim(label: 'grain', phase: AnimationPhase.during),
              anim(label: 'vignette', phase: AnimationPhase.during),
            ],
          ),
        ],
      ),
      scene(
        'outro',
        duration: 3.seconds,
        elements: [
          element(
            'outro',
            animations: [
              anim(label: 'blurIn'),
              anim(label: 'float', phase: AnimationPhase.during),
              anim(label: 'fadeOut', phase: AnimationPhase.exit),
            ],
          ),
        ],
      ),
    ],
  );
}
