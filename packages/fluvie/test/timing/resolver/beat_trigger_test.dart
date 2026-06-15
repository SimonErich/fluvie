import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';

import '../fakes/fake_beat_grid.dart';
import '../helpers/plan_builders.dart';
import '../helpers/resolve_helpers.dart';

void main() {
  // One 10s scene @30fps; 'pulse' lives in a 2s..8s window: frames 60..240.
  CompositionPlan pulsePlan({
    required Trigger at,
    Time delay = Time.zero,
    BeatGrid? defaultBeatGrid,
    Map<Anchor, BeatGrid> trackBeatGrids = const {},
  }) => composition(
    defaultBeatGrid: defaultBeatGrid,
    trackBeatGrids: trackBeatGrids,
    scenes: [
      scene(
        'one',
        duration: 10.seconds,
        elements: [
          element(
            'pulse',
            window: 2.seconds.to(8.seconds),
            animations: [
              anim(at: at, delay: delay, timing: const Tween(Time.frames(20))),
            ],
          ),
        ],
      ),
    ],
  );

  group('Trigger.beat', () {
    test('snaps to the first beat at or after the window start (D8)', () {
      final result = resolvePlan(
        pulsePlan(
          at: const Trigger.beat(),
          defaultBeatGrid: FakeBeatGrid([0, 50, 75, 100]),
        ),
      );

      expect(result.spans[0], const ResolvedSpan(75, 95));
    });

    test('a beat exactly on the window start fires there', () {
      final result = resolvePlan(
        pulsePlan(
          at: const Trigger.beat(),
          defaultBeatGrid: FakeBeatGrid([60, 90]),
        ),
      );

      expect(result.spans[0], const ResolvedSpan(60, 80));
    });

    test('every: n consults only every n-th beat of the grid', () {
      final grid = FakeBeatGrid([0, 61, 64, 90]);

      final everyBeat = resolvePlan(
        pulsePlan(at: const Trigger.beat(), defaultBeatGrid: grid),
      );
      final everySecond = resolvePlan(
        pulsePlan(at: const Trigger.beat(every: 2), defaultBeatGrid: grid),
      );

      expect(everyBeat.spans[0], const ResolvedSpan(61, 81));
      // every: 2 keeps beats 0 and 64 — 61 no longer qualifies.
      expect(everySecond.spans[0], const ResolvedSpan(64, 84));
    });

    test('delay applies after the snapped beat', () {
      final result = resolvePlan(
        pulsePlan(
          at: const Trigger.beat(),
          delay: 0.5.seconds,
          defaultBeatGrid: FakeBeatGrid([75]),
        ),
      );

      expect(result.spans[0], const ResolvedSpan(90, 110));
    });

    test("track: selects that track's grid over the default", () {
      final drums = Anchor('drums');
      final result = resolvePlan(
        pulsePlan(
          at: Trigger.beat(track: drums),
          defaultBeatGrid: FakeBeatGrid([61]),
          trackBeatGrids: {
            drums: FakeBeatGrid([70]),
          },
        ),
      );

      expect(result.spans[0], const ResolvedSpan(70, 90));
    });

    test('a missing grid is a FluvieTimingError (D8)', () {
      // No beat-tagged track at all…
      expect(
        () => resolvePlan(pulsePlan(at: const Trigger.beat())),
        throwsA(
          isA<FluvieTimingError>().having((e) => e.message, 'message', contains('pulse')),
        ),
      );

      // …and a track anchor with no grid behind it, named in the error.
      final drums = Anchor('drums');
      expect(
        () => resolvePlan(
          pulsePlan(
            at: Trigger.beat(track: drums),
            defaultBeatGrid: FakeBeatGrid([70]),
          ),
        ),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.anchors, 'anchors', [drums])
              .having((e) => e.toString(), 'toString', contains('drums')),
        ),
      );
    });

    test('no qualifying beat before the window end is a FluvieTimingError (D8)', () {
      // The only beat lands at/after the window end (frame 240)…
      expect(
        () => resolvePlan(
          pulsePlan(at: const Trigger.beat(), defaultBeatGrid: FakeBeatGrid([250])),
        ),
        throwsA(isA<FluvieTimingError>()),
      );

      // …or the grid runs out before the window starts.
      expect(
        () => resolvePlan(
          pulsePlan(at: const Trigger.beat(), defaultBeatGrid: FakeBeatGrid([10])),
        ),
        throwsA(
          isA<FluvieTimingError>().having((e) => e.message, 'message', contains('pulse')),
        ),
      );
    });

    test('beat resolution is deterministic across runs', () {
      CompositionPlan build() => pulsePlan(
        at: const Trigger.beat(every: 2),
        delay: const Time.frames(5),
        defaultBeatGrid: FakeBeatGrid.everyInterval(45, totalFrames: 300),
      );

      final first = resolvePlan(build());
      final second = resolvePlan(build());

      expect(first.spans, second.spans);
      // every: 2 over 0,45,90,… keeps 0,90,180,… → first ≥ 60 is 90, +5 delay.
      expect(first.spans[0], const ResolvedSpan(95, 115));
    });
  });
}
