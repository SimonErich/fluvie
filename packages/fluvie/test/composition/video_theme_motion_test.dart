// Epic 14.1 (WI-4, D-MotionCascade): a FluvieTheme.motion folds into the
// animation default cascade below Video.motionDefaults and above the package
// default. VideoState reads context.fluvie.motion and threads it as the theme
// layer of mergeDefaultsChain, so a default-timed animation under a theme
// derives its duration / ease from the theme — and an explicit
// Video.motionDefaults always beats it (the precedence pin).

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/theme/fluvie_theme.dart';

const _kFade = Key('themed-fade');

/// A default-timed fade: no explicit `duration:`, so the cascade governs how
/// long it runs. It sits inside a user widget so the build-time registrar must
/// carry the cascade down to it (D1).
class _DefaultFade extends StatelessWidget {
  const _DefaultFade();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: _kFade,
    width: 40,
    height: 40,
  ).animate([Animation.from(const Keyframe(opacity: 0), ease: Ease.linear)]);
}

Video _video({Defaults? motionDefaults}) => Video(
  width: 320,
  height: 240,
  motionDefaults: motionDefaults,
  scenes: const [
    Scene(duration: Time.seconds(10), children: [_DefaultFade()]),
  ],
);

/// Mounts [video] in capture mode under a fresh controller and probe, optionally
/// wrapped in a FluvieTheme with [themeMotion]; pumps once so the post-frame
/// resolve completes.
Future<TimelineProbe> _mount(
  WidgetTester tester, {
  required Video video,
  Defaults? themeMotion,
}) async {
  final probe = TimelineProbe();
  final themed = themeMotion == null
      ? video as Widget
      : FluvieTheme(motion: themeMotion, child: video);
  await tester.pumpWidget(
    RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: RenderController(),
        child: TimelineProbeScope(probe: probe, child: themed),
      ),
    ),
  );
  await tester.pump();
  return probe;
}

void main() {
  group('Video — the FluvieTheme.motion cascade layer (WI-4)', () {
    testWidgets('a default-timed animation derives its duration from the theme', (tester) async {
      // @30fps a 0.5s theme duration is a 15-frame window (0..15).
      final probe = await _mount(
        tester,
        video: _video(),
        themeMotion: const Defaults(duration: Time.seconds(0.5)),
      );
      final row = probe.value!.rowsFor('s0e0:SizedBox').single;
      expect((row.startFrame, row.endFrame), (0, 15));
    });

    testWidgets('with no theme the package default (capped 0.8s = 24 frames) governs', (
      tester,
    ) async {
      final probe = await _mount(tester, video: _video());
      final row = probe.value!.rowsFor('s0e0:SizedBox').single;
      // 20% of a 10s window caps at 0.8s -> 24 frames @30fps.
      expect((row.startFrame, row.endFrame), (0, 24));
    });

    testWidgets('an explicit Video.motionDefaults beats the theme (the precedence pin)', (
      tester,
    ) async {
      // The theme asks for 0.5s, but the Video pins 10 frames — the Video wins.
      final probe = await _mount(
        tester,
        video: _video(motionDefaults: const Defaults(duration: Time.frames(10))),
        themeMotion: const Defaults(duration: Time.seconds(0.5)),
      );
      final row = probe.value!.rowsFor('s0e0:SizedBox').single;
      expect((row.startFrame, row.endFrame), (0, 10));
    });

    testWidgets('the theme ease reaches the rendered animation', (tester) async {
      // A 10-frame linear fade from the theme: opacity is exactly 0.5 at the
      // midpoint, which only holds for a linear curve.
      final controller = RenderController();
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: RenderControllerScope(
            controller: controller,
            child: FluvieTheme(
              motion: const Defaults(duration: Time.frames(10), ease: Ease.linear),
              child: Video(
                width: 320,
                height: 240,
                scenes: const [
                  Scene(duration: Time.seconds(10), children: [_DefaultFade()]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.seek(5);
      await tester.pump();
      final opacity = tester
          .widgetList<Opacity>(find.byType(Opacity, skipOffstage: false))
          .map((o) => o.opacity);
      expect(opacity, contains(closeTo(0.5, 1e-9)));
    });

    testWidgets('a theme change re-resolves the schedule (didChangeDependencies)', (tester) async {
      final controller = RenderController();
      final probe = TimelineProbe();
      Widget tree(Defaults motion) => RenderModeContext(
        mode: RenderMode.capture,
        child: RenderControllerScope(
          controller: controller,
          child: TimelineProbeScope(
            probe: probe,
            child: FluvieTheme(
              motion: motion,
              child: Video(
                width: 320,
                height: 240,
                scenes: const [
                  Scene(duration: Time.seconds(10), children: [_DefaultFade()]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree(const Defaults(duration: Time.frames(10))));
      await tester.pump();
      expect(probe.value!.rowsFor('s0e0:SizedBox').single.endFrame, 10);

      await tester.pumpWidget(tree(const Defaults(duration: Time.frames(20))));
      await tester.pump();
      await tester.pump();
      expect(probe.value!.rowsFor('s0e0:SizedBox').single.endFrame, 20);
    });
  });
}
