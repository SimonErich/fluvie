import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';

const _kAnchor = Key('anchor');
const _kFollower = Key('follower');
const _kThird = Key('third');
const _kNested = Key('nested');

Animation _fade(int frames, {Trigger at = Trigger.auto}) => Animation.from(
  const Keyframe(opacity: 0),
  duration: Time.frames(frames),
  ease: Ease.linear,
  at: at,
);

/// The §3-shaped acceptance composition minus Background (WI-18): an anchored
/// fade, a follower gated on `Trigger.after`, and a third element chaining
/// `previous` off its own first animation.
Video _quickstartVideo() {
  final bg = Anchor('bg');
  return Video(
    width: 320,
    height: 240,
    scenes: [
      Scene(
        duration: 90.frames,
        children: [
          const SizedBox(key: _kAnchor, width: 40, height: 40).animate([_fade(30)], anchor: bg),
          const Text(
            'follower',
            key: _kFollower,
            textDirection: TextDirection.ltr,
          ).animate([_fade(20, at: Trigger.after(bg))]),
          const SizedBox(key: _kThird, width: 10, height: 10).animate([
            _fade(10, at: Trigger.after(bg)),
            Animation.to(
              const Keyframe(y: 0.5),
              duration: const Time.frames(10),
              ease: Ease.linear,
              at: Trigger.previous,
            ),
          ]),
        ],
      ),
    ],
  );
}

/// Mounts [video] in capture mode under [controller] (and a probe when
/// given) — the render-harness shape the D1 determinism argument relies on.
Widget _harness(Video video, {required RenderController controller, TimelineProbe? probe}) =>
    RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: controller,
        child: probe == null ? video : TimelineProbeScope(probe: probe, child: video),
      ),
    );

// FadeBox replaced the raw Opacity (D16-P6); it stays mounted at 1.0.
double _opacityOf(WidgetTester tester, Key key) => tester
    .widget<FadeBox>(
      find
          .ancestor(
            of: find.byKey(key, skipOffstage: false),
            matching: find.byType(FadeBox, skipOffstage: false),
          )
          .first,
    )
    .opacity;

void main() {
  group('Video registrar integration — §3-shaped acceptance (WI-18, D1)', () {
    testWidgets('the follower waits for the anchor union span, frame by frame', (tester) async {
      final controller = RenderController();
      await tester.pumpWidget(_harness(_quickstartVideo(), controller: controller));

      Future<double> opacityAt(Key key, int frame) async {
        controller.seek(frame);
        await tester.pump();
        return _opacityOf(tester, key);
      }

      // The anchor fades 0..30.
      expect(await opacityAt(_kAnchor, 0), 0.0);
      expect(await opacityAt(_kAnchor, 15), closeTo(0.5, 1e-9));
      expect(await opacityAt(_kAnchor, 30), 1.0);
      // The follower holds hidden until the anchor's span ends at 30…
      expect(await opacityAt(_kFollower, 15), 0.0);
      expect(await opacityAt(_kFollower, 29), 0.0);
      // …then fades 30..50.
      expect(await opacityAt(_kFollower, 30), 0.0);
      expect(await opacityAt(_kFollower, 40), closeTo(0.5, 1e-9));
      expect(await opacityAt(_kFollower, 50), 1.0);
      // The third element: fade 30..40, then `previous` slides it 40..50.
      expect(await opacityAt(_kThird, 35), closeTo(0.5, 1e-9));
      controller.seek(45);
      await tester.pump();
      final slide = tester.widget<FractionalTranslation>(
        find.ancestor(of: find.byKey(_kThird), matching: find.byType(FractionalTranslation)).first,
      );
      expect(slide.translation.dy, closeTo(0.25, 1e-9));
    });

    testWidgets('the probe receives a warning-free timeline with D19 ownerIds', (tester) async {
      final controller = RenderController();
      final probe = TimelineProbe();
      await tester.pumpWidget(_harness(_quickstartVideo(), controller: controller, probe: probe));
      await tester.pump();

      final timeline = probe.value;
      expect(timeline, isNotNull);
      expect(timeline!.warnings, isEmpty);
      expect(timeline.totalFrames, 90);
      final text = debugTimeline(timeline);
      expect(text, contains('s0e0:bg'));
      expect(text, contains('s0e1:Text'));
      expect(text, contains('s0e2:SizedBox'));
      expect(timeline.rowsFor('s0e2:SizedBox').map((row) => (row.startFrame, row.endFrame)), [
        (30, 40),
        (40, 50),
      ]);
      // The State's test surface agrees with the probe.
      final state = tester.state<VideoState>(find.byType(Video));
      expect(state.resolvedTimeline, same(timeline));
    });
  });

  group('Video registrar integration — the Defaults cascade (WI-18, D17)', () {
    testWidgets('scene defaults reach a nested element through the registrar schedule', (
      tester,
    ) async {
      // Duration from the video layer, ease from the scene layer — and the
      // element is hidden inside a user StatelessWidget, which is exactly
      // what the build-time registrar exists for (D1).
      final controller = RenderController();
      final probe = TimelineProbe();
      final video = Video(
        width: 320,
        height: 240,
        motionDefaults: const Defaults(duration: Time.frames(10)),
        scenes: [
          Scene(duration: 60.frames),
          Scene(
            duration: 30.frames,
            motionDefaults: const Defaults(ease: Ease.linear),
            children: const [_NestedFade()],
          ),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: controller, probe: probe));
      await tester.pump();

      // Scene 2 starts at frame 60; the cascade yields a 10-frame linear
      // fade 60..70, so frame 65 sits at exactly 0.5.
      controller.seek(65);
      await tester.pump();
      expect(_opacityOf(tester, _kNested), closeTo(0.5, 1e-9));
      final row = probe.value!.rowsFor('s1e0:SizedBox').single;
      expect((row.startFrame, row.endFrame), (60, 70));
    });
  });

  group('Video registrar integration — determinism pins (WI-18, D1)', () {
    testWidgets('two frame sweeps over one mount yield identical opacity sequences', (
      tester,
    ) async {
      final controller = RenderController();
      await tester.pumpWidget(_harness(_quickstartVideo(), controller: controller));

      Future<List<(double, double, double)>> sweep() async {
        final samples = <(double, double, double)>[];
        for (var frame = 0; frame <= 60; frame += 5) {
          controller.seek(frame);
          await tester.pump();
          samples.add((
            _opacityOf(tester, _kAnchor),
            _opacityOf(tester, _kFollower),
            _opacityOf(tester, _kThird),
          ));
        }
        return samples;
      }

      expect(await sweep(), await sweep());
    });

    testWidgets('a re-mount resolves to byte-identical debugTimeline text', (tester) async {
      Future<String> mountAndDump() async {
        final probe = TimelineProbe();
        await tester.pumpWidget(
          _harness(_quickstartVideo(), controller: RenderController(), probe: probe),
        );
        await tester.pump();
        final text = debugTimeline(probe.value!);
        await tester.pumpWidget(const SizedBox.shrink());
        return text;
      }

      expect(await mountAndDump(), await mountAndDump());
    });

    testWidgets('capture-mode pin: frame 0 shows resolved state after one seek/pump (D1)', (
      tester,
    ) async {
      // An exit fade is visible (opacity 1) at frame 0 once resolved; the
      // pass-1 placeholder would be hidden (opacity 0). The harness order —
      // pumpWidget, then seek(f) + pump before EVERY capture — therefore can
      // never capture pass-1 output.
      final controller = RenderController();
      final video = Video(
        width: 320,
        height: 240,
        scenes: [
          Scene(
            duration: 60.frames,
            children: [
              const SizedBox(key: _kAnchor, width: 40, height: 40).animate([
                Animation.to(
                  const Keyframe(opacity: 0),
                  duration: const Time.frames(20),
                  ease: Ease.linear,
                ),
              ]),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: controller));
      controller.seek(0);
      await tester.pump();
      expect(_opacityOf(tester, _kAnchor), 1.0);
    });
  });

  group('Video registrar integration — didUpdateWidget reset (WI-18, D6)', () {
    testWidgets('a non-identical scenes list re-collects and re-resolves', (tester) async {
      final controller = RenderController();
      final probe = TimelineProbe();
      Video buildVideo(int fadeFrames) => Video(
        width: 320,
        height: 240,
        scenes: [
          Scene(
            duration: 60.frames,
            children: [
              const SizedBox(key: _kAnchor, width: 40, height: 40).animate([
                _fade(fadeFrames),
              ]),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_harness(buildVideo(20), controller: controller, probe: probe));
      await tester.pump();
      expect(probe.value!.rows.single.endFrame, 20);

      await tester.pumpWidget(_harness(buildVideo(40), controller: controller, probe: probe));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(probe.value!.rows.single.endFrame, 40);
      // The new schedule drives rendering: a 40-frame fade is 0.5 at 20.
      controller.seek(20);
      await tester.pump();
      expect(_opacityOf(tester, _kAnchor), closeTo(0.5, 1e-9));
    });
  });
}

/// A user-style wrapper proving registrations are discovered through opaque
/// widgets — a static walk of `Scene.children` could never see this (D1).
final class _NestedFade extends StatelessWidget {
  const _NestedFade();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: _kNested,
    width: 20,
    height: 20,
  ).animate([Animation.from(const Keyframe(opacity: 0))]);
}
