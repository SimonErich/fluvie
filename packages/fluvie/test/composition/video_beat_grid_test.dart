// Epic 14.5 (WI-22, D-BeatWiring): a BeatGridScope above the Video closes
// Trigger.beat (P13-BEAT-01). VideoState._resolveSchedules reads
// BeatGridScope.maybeOf(context) and threads its default/per-track grids into
// buildVideoPlan, so a Trigger.beat animation resolves to the grid's beat frame
// in capture. Without the scope (or with an empty one) the FluvieTimingError is
// caught in _resolveSchedules and reported to the TimelineProbe rather than
// thrown up to the Flutter scheduler — so the inspector can show it inline.
// The grid arrives via context, not a Video constructor param — the §11 Video
// surface stays unchanged.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/capture/beat_grid_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

import '../timing/fakes/fake_beat_grid.dart';

const _kPop = Key('beat-pop');

/// A fade fired on the beat: a fixed 10-frame linear window so the resolved
/// span is exactly `beat..beat+10` — no grid, no resolution is the wiring under
/// test.
Widget _beatPop({Anchor? track}) =>
    const SizedBox(
      key: _kPop,
      width: 40,
      height: 40,
    ).animate([
      Animation.fadeIn(
        at: Trigger.beat(track: track),
        duration: const Time.frames(10),
        ease: Ease.linear,
      ),
    ]);

Video _video({Anchor? track}) => Video(
  width: 320,
  height: 240,
  scenes: [
    Scene(
      duration: const Time.seconds(10),
      children: [_beatPop(track: track)],
    ),
  ],
);

/// Mounts [video] in capture mode, optionally under a [BeatGridScope] carrying
/// [defaultGrid]/[trackGrids]; pumps once so the post-frame resolve completes.
/// Returns the probe so the test can read the resolved timeline.
Future<TimelineProbe> _mount(
  WidgetTester tester, {
  required Video video,
  BeatGrid? defaultGrid,
  Map<Anchor, BeatGrid> trackGrids = const {},
  bool withScope = true,
}) async {
  final probe = TimelineProbe();
  Widget tree = TimelineProbeScope(probe: probe, child: video);
  if (withScope) {
    tree = BeatGridScope(
      defaultBeatGrid: defaultGrid,
      trackBeatGrids: trackGrids,
      child: tree,
    );
  }
  await tester.pumpWidget(
    RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(controller: RenderController(), child: tree),
    ),
  );
  await tester.pump();
  return probe;
}

void main() {
  group('Video — Trigger.beat through a BeatGridScope (WI-22)', () {
    testWidgets('resolves to the grid default beat frame', (tester) async {
      // Beats at 0, 45, 90; the window starts at the scene start (0), so the
      // first qualifying beat is 0 — the pop runs 0..10.
      final probe = await _mount(
        tester,
        video: _video(),
        defaultGrid: FakeBeatGrid(const [0, 45, 90]),
      );
      final row = probe.value!.rowsFor('s0e0:SizedBox').single;
      expect((row.startFrame, row.endFrame), (0, 10));
    });

    testWidgets('snaps to a later beat when the first is past the window start', (tester) async {
      // No beat at 0; the first qualifying beat is 30, so the pop runs 30..40.
      final probe = await _mount(
        tester,
        video: _video(),
        defaultGrid: FakeBeatGrid(const [30, 60]),
      );
      final row = probe.value!.rowsFor('s0e0:SizedBox').single;
      expect((row.startFrame, row.endFrame), (30, 40));
    });

    testWidgets('a track: anchor selects that grid over the default', (tester) async {
      final drums = Anchor('drums');
      final probe = await _mount(
        tester,
        video: _video(track: drums),
        defaultGrid: FakeBeatGrid(const [0]),
        trackGrids: {
          drums: FakeBeatGrid(const [12]),
        },
      );
      final row = probe.value!.rowsFor('s0e0:SizedBox').single;
      expect((row.startFrame, row.endFrame), (12, 22));
    });

    testWidgets('a beat-pop resolves deterministically across two mounts', (tester) async {
      final grid = FakeBeatGrid(const [15]);
      final first = await _mount(tester, video: _video(), defaultGrid: grid);
      final firstRow = first.value!.rowsFor('s0e0:SizedBox').single;
      final second = await _mount(tester, video: _video(), defaultGrid: grid);
      final secondRow = second.value!.rowsFor('s0e0:SizedBox').single;
      expect((firstRow.startFrame, firstRow.endFrame), (secondRow.startFrame, secondRow.endFrame));
    });

    testWidgets(
      'without a BeatGridScope it reports the honest timing error via the probe',
      (tester) async {
        final probe = await _mount(tester, video: _video(), withScope: false);
        expect(tester.takeException(), isNull);
        expect(probe.timingError, isNotNull);
        expect(probe.timingError, contains('no grid to'));
      },
    );

    testWidgets(
      'an empty BeatGridScope reports a timing error (no default grid)',
      (tester) async {
        // A scope mounts, but it carries no grid at all, so the resolver still
        // meets a beat trigger with nothing to resolve against.
        final probe = await _mount(tester, video: _video());
        expect(tester.takeException(), isNull);
        expect(probe.timingError, isNotNull);
      },
    );

    testWidgets(
      'a track: beat with no matching grid reports a timing error naming the track',
      (tester) async {
        final drums = Anchor('drums');
        final probe = await _mount(
          tester,
          video: _video(track: drums),
          defaultGrid: FakeBeatGrid(const [0]),
        );
        expect(tester.takeException(), isNull);
        expect(probe.timingError, isNotNull);
        // The anchor name flows through error.toString() → "(anchors: drums)".
        expect(probe.timingError, contains('drums'));
      },
    );

    testWidgets(
      'without a probe, a FluvieTimingError is surfaced via FlutterError (not swallowed)',
      (tester) async {
        // This simulates a Video with Trigger.beat used outside the inspector
        // (no TimelineProbeScope mounted). The error must not silently vanish.
        final errors = <FlutterErrorDetails>[];
        final original = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = original);

        // _mount always mounts a probe. Re-mount manually without one.
        final video = _video();
        await tester.pumpWidget(
          RenderModeContext(
            mode: RenderMode.capture,
            child: RenderControllerScope(controller: RenderController(), child: video),
          ),
        );
        await tester.pump();

        // The probe path is absent, so VideoState falls back to FlutterError.
        expect(tester.takeException(), isNull); // not rethrown to the scheduler
        expect(errors, hasLength(1));
        expect(errors.single.exception, isA<FluvieTimingError>());
      },
    );

    testWidgets('a grid-less Video (no Trigger.beat) is unaffected by the scope', (tester) async {
      final plain = Video(
        width: 320,
        height: 240,
        scenes: const [
          Scene(
            duration: Time.seconds(10),
            children: [SizedBox(width: 10, height: 10)],
          ),
        ],
      );
      final probe = await _mount(tester, video: plain, defaultGrid: FakeBeatGrid(const [0]));
      expect(probe.value, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
