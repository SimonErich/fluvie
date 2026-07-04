import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _square = SizedBox(width: 20, height: 20, child: ColoredBox(color: Color(0xFF334455)));

/// Mounts [child] under the full frame + timing harness at [frame]: a 30 fps
/// video with one scene of [sceneFrames] frames.
Widget _harness({required int frame, required int sceneFrames, required Widget child}) =>
    RenderControllerScope(
      controller: RenderController(initialFrame: frame),
      child: VideoScope(
        fps: 30,
        duration: Time.frames(sceneFrames),
        child: SceneScope(duration: Time.frames(sceneFrames), child: child),
      ),
    );

void main() {
  group('repeat end-to-end — spin cycle math (D12)', () {
    Future<Matrix4?> rotationAt(WidgetTester tester, int frame) async {
      await tester.pumpWidget(
        _harness(
          frame: frame,
          sceneFrames: 240,
          child: _square.animate([Animation.spin(per: const Time.frames(120))]),
        ),
      );
      final finder = find.byType(Transform);
      if (finder.evaluate().isEmpty) return null;
      return tester.widget<Transform>(finder).transform;
    }

    testWidgets('spin over a 240-frame window completes exactly 2 turns at frame 240', (
      tester,
    ) async {
      // Frame 0: rotation 0 is the identity — nothing mounts.
      expect(await rotationAt(tester, 0), isNull);
      // Frame 60: half a turn into cycle 1 — cos(π) = −1.
      expect((await rotationAt(tester, 60))!.storage[0], closeTo(-1, 1e-12));
      // Frame 120: the cycle boundary restarts at rotation 0 — turn 1 done.
      expect(await rotationAt(tester, 120), isNull);
      // Frame 180: half a turn into cycle 2.
      expect((await rotationAt(tester, 180))!.storage[0], closeTo(-1, 1e-12));
      // Frame 239: one frame short of completing turn 2 — 119/120 of 2π,
      // approaching the identity from below (sin just negative).
      final almost = (await rotationAt(tester, 239))!;
      expect(almost.storage[0], closeTo(0.99862953475, 1e-9)); // cos(−2π/120)
      expect(almost.storage[1], closeTo(-0.05233595624, 1e-9)); // sin(−2π/120)
      // Frame 240: exactly 2 turns completed — the wheel is back at the
      // identity on the dot (a forever repeat fills the span, D12).
      expect(await rotationAt(tester, 240), isNull);
    });
  });

  group('repeat end-to-end — Repeat.times with a gap (D12)', () {
    Future<double> opacityAt(WidgetTester tester, int frame) async {
      await tester.pumpWidget(
        _harness(
          frame: frame,
          sceneFrames: 60,
          child: _square.animate([
            Animation.fromTo(
              const Keyframe(opacity: 0),
              const Keyframe(opacity: 1),
              phase: AnimationPhase.during,
              duration: const Time.frames(10),
              ease: Ease.linear,
              repeat: const Repeat.times(2, gap: Time.frames(6)),
            ),
          ]),
        ),
      );
      // FadeBox replaced the raw Opacity (D16-P6) and stays mounted at 1.0.
      return tester.widget<FadeBox>(find.byType(FadeBox)).opacity;
    }

    testWidgets('the gap holds the just-reached endpoint at exact frames', (tester) async {
      // Cycle 1 ramps over frames 0..10…
      expect(await opacityAt(tester, 5), closeTo(0.5, 1e-9));
      expect(await opacityAt(tester, 10), 1.0);
      // …the 6-frame gap holds the endpoint…
      expect(await opacityAt(tester, 12), 1.0);
      expect(await opacityAt(tester, 15), 1.0);
      // …cycle 2 restarts at frame 16 and ramps again…
      expect(await opacityAt(tester, 16), 0.0);
      expect(await opacityAt(tester, 21), closeTo(0.5, 1e-9));
      expect(await opacityAt(tester, 26), 1.0);
      // …and times(2) holds the final endpoint to the span end.
      expect(await opacityAt(tester, 40), 1.0);
      expect(await opacityAt(tester, 59), 1.0);
    });
  });

  testWidgets('repeat on an enter phase holds the endpoint past its span (D12)', (tester) async {
    // fadeIn with Repeat.times(2) over a 20-frame span: frames past the span
    // must hold opacity 1.0 -- extra cycles never render on enter/exit.
    final controller = RenderController(initialFrame: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      RenderControllerScope(
        controller: controller,
        child: VideoScope(
          fps: 30,
          duration: const Time.frames(60),
          child: SceneScope(
            duration: const Time.frames(60),
            child:
                const ColoredBox(
                  color: Color(0xFF112233),
                ).animate([
                  Animation.fadeIn(
                    duration: const Time.frames(20),
                    ease: Ease.linear,
                    repeat: const Repeat.times(2),
                  ),
                ]),
          ),
        ),
      ),
    );

    final opacity = tester.widget<FadeBox>(find.byType(FadeBox).first);
    expect(opacity.opacity, 1.0, reason: 'enter must hold its endpoint, not replay cycle 2');
  });
}
