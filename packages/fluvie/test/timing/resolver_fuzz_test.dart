import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/plan/scene_plan.dart';
import 'package:fluvie/src/timing/resolver/composition_resolver.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';

/// Randomised properties of the whole resolution pipeline. Every generator is
/// driven by a seeded [math.Random] (tests are exempt from the random ban,
/// but every seed is fixed), so failures reproduce exactly: the failing seed
/// is in the assertion reason.
///
/// Plans are acyclic by construction — triggers only ever reference anchors
/// of *already-declared* elements, and `Trigger.previous` is only used past
/// an element's first animation. `Trigger.beat` is excluded: a fuzzed window
/// with no qualifying beat is a *designed* error (D8), which would drown the
/// "no exception escapes" property in expected failures.
///
/// `during`-phase animations fuzz with arbitrary triggers and delays: a
/// trigger firing past the window end inverts the span by design, and the
/// property asserts the resolver warns about every inverted row.
const _iterations = 200;

void main() {
  group('resolver fuzz', () {
    test('well-formed plans resolve: spans ordered, in bounds or warned, never throwing', () {
      var rowsSeen = 0;
      var outOfBoundsSeen = 0;
      for (var seed = 0; seed < _iterations; seed++) {
        final plan = _randomPlan(math.Random(seed));

        final detailed = resolveCompositionDetailed(plan); // must not throw
        final timeline = detailed.timeline;
        final windowByOwner = {
          for (final entry in detailed.windows.entries) entry.key.ownerId: entry.value,
        };

        for (final row in timeline.rows) {
          rowsSeen += 1;
          // Frames are ints — NaN is unrepresentable; guard absurd magnitudes
          // (a NaN-like blowup in upstream double math would surface here).
          expect(row.startFrame.abs(), lessThan(1 << 32), reason: 'seed $seed: $row');
          if (row.endFrame < row.startFrame) {
            // A `during` trigger firing at/after its window end inverts the
            // span by design; the resolver must surface it as a warning.
            expect(
              timeline.warnings.any(
                (warning) => warning.contains("'${row.ownerId}'") && warning.contains('inverted'),
              ),
              isTrue,
              reason: 'seed $seed: inverted span in $row carries no warning',
            );
          }
          final window = windowByOwner[row.ownerId]!;
          final fitsWindow = row.startFrame >= window.start && row.endFrame <= window.end;
          final fitsVideo = row.startFrame >= 0 && row.endFrame <= timeline.totalFrames;
          if (!fitsWindow || !fitsVideo) {
            outOfBoundsSeen += 1;
            expect(
              timeline.warnings.any((warning) => warning.contains("'${row.ownerId}'")),
              isTrue,
              reason: 'seed $seed: $row is out of bounds but no warning names its owner',
            );
          }
        }
      }
      // Vacuity guards: the fixed seed range must actually exercise both the
      // happy path (rows at all) and the D9 warning path.
      expect(rowsSeen, greaterThan(500));
      expect(outOfBoundsSeen, greaterThan(10));
    });

    test('resolution is deterministic per seed, down to the timeline dump bytes', () {
      for (var seed = 0; seed < _iterations; seed++) {
        final first = debugTimeline(resolveComposition(_randomPlan(math.Random(seed))));
        final second = debugTimeline(resolveComposition(_randomPlan(math.Random(seed))));

        expect(first, second, reason: 'seed $seed');
      }
    });

    test('independent (auto-triggered) declarations keep declaration order', () {
      for (var seed = 0; seed < _iterations; seed++) {
        final random = math.Random(seed);
        final labels = <String>[];
        final scenes = <ScenePlan>[];
        for (var s = 0; s < 1 + random.nextInt(4); s++) {
          final elements = <ElementPlan>[];
          for (var e = 0; e < random.nextInt(7); e++) {
            final animations = <AnimationPlan>[];
            for (var a = 0; a < random.nextInt(5); a++) {
              final label = 's${s}e${e}a$a';
              labels.add(label);
              // Equal starts by construction: enter + auto + zero delay means
              // every row in scene s starts at the scene's start frame.
              animations.add(
                AnimationPlan(
                  phase: AnimationPhase.enter,
                  timing: Tween(Time.frames(1 + random.nextInt(90))),
                  label: label,
                ),
              );
            }
            elements.add(ElementPlan(ownerId: 's${s}e$e', animations: animations));
          }
          scenes.add(
            ScenePlan(
              id: 'scene$s',
              duration: Time.frames(30 + random.nextInt(211)),
              elements: elements,
            ),
          );
        }

        final timeline = resolveComposition(CompositionPlan(fps: 30, scenes: scenes));

        expect(
          timeline.rows.map((row) => row.label).toList(),
          labels,
          reason: 'seed $seed: equal-start rows must keep declaration order',
        );
      }
    });

    test(
      'a forced back-edge always throws FluvieTimingError — bounded, never hanging',
      () {
        for (var seed = 0; seed < _iterations; seed++) {
          final random = math.Random(seed);
          final plan = _randomPlan(random);
          final withCycle = _plantCycle(plan, random);

          expect(
            () => resolveComposition(withCycle),
            throwsA(isA<FluvieTimingError>()),
            reason: 'seed $seed',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// A random well-formed plan: 1–4 scenes of 30–240 frames, 0–6 elements each,
/// 0–4 animations each, random windows/timings/delays, and triggers that only
/// reference anchors declared before them.
CompositionPlan _randomPlan(math.Random random) {
  final declared = <Anchor>[];
  final scenes = <ScenePlan>[];
  for (var s = 0; s < 1 + random.nextInt(4); s++) {
    final elements = <ElementPlan>[];
    for (var e = 0; e < random.nextInt(7); e++) {
      final ownerId = 's${s}e$e';
      final anchor = random.nextBool() ? Anchor(ownerId) : null;
      final animations = [
        for (var a = 0; a < random.nextInt(5); a++)
          _randomAnimation(random, animationIndex: a, declared: declared, label: '${ownerId}a$a'),
      ];
      elements.add(
        ElementPlan(
          ownerId: ownerId,
          anchor: anchor,
          window: _randomWindow(random),
          animations: animations,
        ),
      );
      // Pool the anchor only *after* its element: an element never triggers
      // off itself, so reference edges always point forward (acyclic).
      if (anchor != null) declared.add(anchor);
    }
    scenes.add(
      ScenePlan(
        id: 'scene$s',
        duration: Time.frames(30 + random.nextInt(211)),
        elements: elements,
      ),
    );
  }
  return CompositionPlan(fps: 30, scenes: scenes);
}

/// `null` (whole scene) 60% of the time, else an ordered pair of relative or
/// absolute endpoints (ordering the raw values keeps the range non-inverted
/// at any fps; the resolver clamps overhang into the scene).
TimeRange? _randomWindow(math.Random random) {
  if (random.nextDouble() < 0.6) return null;
  if (random.nextBool()) {
    final a = random.nextDouble();
    final b = random.nextDouble();
    return TimeRange(Time.relative(math.min(a, b)), Time.relative(math.max(a, b)));
  }
  final a = random.nextInt(260);
  final b = random.nextInt(260);
  return TimeRange(Time.frames(math.min(a, b)), Time.frames(math.max(a, b)));
}

AnimationPlan _randomAnimation(
  math.Random random, {
  required int animationIndex,
  required List<Anchor> declared,
  required String label,
}) {
  final timing = _randomTiming(random);
  final named = random.nextBool() ? label : null;
  final phase = switch (random.nextInt(3)) {
    0 => AnimationPhase.during,
    1 => AnimationPhase.enter,
    _ => AnimationPhase.exit,
  };
  return AnimationPlan(
    phase: phase,
    timing: timing,
    delay: _randomDelay(random),
    at: _randomTrigger(random, animationIndex: animationIndex, declared: declared),
    label: named,
  );
}

/// A `Tween` with a random absolute or relative duration, a `Spring` with
/// non-zero damping (a zero-damping spring never settles, by design an
/// error), or `null` to exercise the defaults cascade.
Timing? _randomTiming(math.Random random) => switch (random.nextInt(3)) {
  0 => null,
  1 => Tween(
    random.nextBool() ? Time.frames(random.nextInt(91)) : Time.relative(random.nextDouble() * 0.5),
  ),
  _ => Spring(
    stiffness: 50 + random.nextDouble() * 450,
    damping: 5 + random.nextDouble() * 25,
    mass: 0.5 + random.nextDouble() * 1.5,
  ),
};

Time _randomDelay(math.Random random) => switch (random.nextInt(3)) {
  0 => Time.zero,
  1 => Time.frames(random.nextInt(46)),
  _ => Time.relative(random.nextDouble() * 0.2),
};

Trigger _randomTrigger(
  math.Random random, {
  required int animationIndex,
  required List<Anchor> declared,
}) {
  final options = <Trigger>[
    Trigger.auto,
    Trigger.sceneStart,
    Trigger.sceneEnd,
    Trigger.at(Time.frames(random.nextInt(200))),
    if (animationIndex > 0) Trigger.previous,
    if (declared.isNotEmpty) Trigger.after(declared[random.nextInt(declared.length)]),
    if (declared.isNotEmpty) Trigger.whenStarts(declared[random.nextInt(declared.length)]),
  ];
  return options[random.nextInt(options.length)];
}

/// Appends a scene whose elements form a deliberate 2- or 3-cycle of
/// `Trigger.after` references — the back-edge the resolver must always reject.
CompositionPlan _plantCycle(CompositionPlan plan, math.Random random) {
  final length = 2 + random.nextInt(2);
  final anchors = [for (var i = 0; i < length; i++) Anchor('cycle$i')];
  final elements = [
    for (var i = 0; i < length; i++)
      ElementPlan(
        ownerId: 'cycle$i',
        anchor: anchors[i],
        animations: [
          AnimationPlan(
            phase: AnimationPhase.enter,
            at: Trigger.after(anchors[(i + 1) % length]),
          ),
        ],
      ),
  ];
  return CompositionPlan(
    fps: plan.fps,
    scenes: [
      ...plan.scenes,
      ScenePlan(id: 'cycle-scene', duration: const Time.frames(60), elements: elements),
    ],
  );
}
