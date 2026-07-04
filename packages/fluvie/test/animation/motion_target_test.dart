import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/schedule/resolved_schedule_scope.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _square = SizedBox(width: 20, height: 20, child: ColoredBox(color: Color(0xFF334455)));

/// Mounts [child] under the full frame + timing harness at [frame]:
/// a 60-frame, 30 fps video with one whole-length scene.
Widget _harness({required int frame, required Widget child}) => RenderControllerScope(
  controller: RenderController(initialFrame: frame),
  child: VideoScope(
    fps: 30,
    duration: const Time.frames(60),
    child: SceneScope(duration: const Time.frames(60), child: child),
  ),
);

Animation _fade() => Animation.from(
  const Keyframe(opacity: 0),
  duration: const Time.frames(20),
  ease: Ease.linear,
);

void main() {
  group('MotionTarget — local resolution (D15)', () {
    Future<double?> opacityAt(WidgetTester tester, int frame) async {
      await tester.pumpWidget(
        _harness(
          frame: frame,
          child: MotionTarget(animations: [_fade()], child: _square),
        ),
      );
      // The FadeBox primitive replaced the raw Opacity (D16-P6): it is
      // mounted for every non-null composed opacity, 1.0 included.
      final finder = find.byType(FadeBox);
      if (finder.evaluate().isEmpty) return null;
      return tester.widget<FadeBox>(finder).opacity;
    }

    testWidgets('a fade shows expected opacity at the start, middle, and end', (tester) async {
      expect(await opacityAt(tester, 0), 0.0);
      expect(await opacityAt(tester, 10), closeTo(0.5, 1e-9));
      expect(await opacityAt(tester, 20), 1.0);
    });

    testWidgets('a relative delay inside a window resolves against the window', (tester) async {
      // Window 30..60: 0.5.relative of its 30 frames is a 15-frame delay, so
      // the 10-frame fade runs 45..55 and frame 50 sits at progress 0.5.
      await tester.pumpWidget(
        _harness(
          frame: 50,
          child: MotionTarget(
            animations: [
              Animation.from(
                const Keyframe(opacity: 0),
                duration: const Time.frames(10),
                ease: Ease.linear,
                delay: 0.5.relative,
              ),
            ],
            window: 30.frames.to(60.frames),
            child: _square,
          ),
        ),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, closeTo(0.5, 1e-9));
    });

    testWidgets('mounts a WindowScope so descendants resolve against the window', (tester) async {
      late TimeScopeData seen;
      await tester.pumpWidget(
        _harness(
          frame: 35,
          child: MotionTarget(
            animations: const [],
            window: 30.frames.to(50.frames),
            child: Builder(
              builder: (context) {
                seen = TimeScopeProvider.of(context);
                return _square;
              },
            ),
          ),
        ),
      );
      expect(seen.startFrame, 30);
      expect(seen.durationFrames, 20);
    });
  });

  group('MotionTarget — missing providers', () {
    testWidgets('no FrameProvider throws a FluvieTimingError naming RenderControllerScope', (
      tester,
    ) async {
      await tester.pumpWidget(MotionTarget(animations: [_fade()], child: _square));
      expect(
        tester.takeException(),
        isA<FluvieTimingError>().having(
          (e) => e.message,
          'message',
          contains('RenderControllerScope'),
        ),
      );
    });

    testWidgets('no TimeScope throws a FluvieTimingError', (tester) async {
      await tester.pumpWidget(
        RenderControllerScope(
          controller: RenderController(),
          child: MotionTarget(animations: [_fade()], child: _square),
        ),
      );
      expect(
        tester.takeException(),
        isA<FluvieTimingError>().having((e) => e.message, 'message', contains('TimeScope')),
      );
    });
  });

  group('MotionTarget — the schedule seam (D14)', () {
    testWidgets('an injected ResolvedScheduleScope overrides local resolution', (tester) async {
      // Locally the fade would resolve to 0..20 (opacity 0.5 at frame 10);
      // the injected schedule shifts it to 10..30, so frame 10 is its very
      // start — the injected spans are provably the ones consumed.
      const injected = ElementSchedule(
        window: ResolvedSpan(0, 60),
        spans: [ResolvedSpan(10, 30)],
        defaults: Defaults(duration: Time.frames(20), ease: Ease.linear),
      );
      await tester.pumpWidget(
        _harness(
          frame: 10,
          child: ResolvedScheduleScope(
            schedule: injected,
            child: MotionTarget(animations: [_fade()], child: _square),
          ),
        ),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.0);
    });

    testWidgets('a spans/animations length mismatch throws a FluvieTimingError', (tester) async {
      const mismatched = ElementSchedule(
        window: ResolvedSpan(0, 60),
        spans: [ResolvedSpan(0, 20), ResolvedSpan(20, 40)],
        defaults: Defaults(duration: Time.frames(20), ease: Ease.linear),
      );
      await tester.pumpWidget(
        _harness(
          frame: 0,
          child: ResolvedScheduleScope(
            schedule: mismatched,
            child: MotionTarget(animations: [_fade()], child: _square),
          ),
        ),
      );
      expect(
        tester.takeException(),
        isA<FluvieTimingError>().having((e) => e.message, 'message', contains('2 spans')),
      );
    });
  });

  group('MotionTarget — cross-element triggers (D15)', () {
    testWidgets('a cross-element trigger rethrows with Phase-6 guidance', (tester) async {
      await tester.pumpWidget(
        _harness(
          frame: 0,
          child: MotionTarget(
            animations: [
              Animation.from(const Keyframe(opacity: 0), at: Trigger.whenEnds(Anchor('other'))),
            ],
            child: _square,
          ),
        ),
      );
      expect(
        tester.takeException(),
        isA<FluvieTimingError>().having(
          (e) => e.message,
          'message',
          contains('composition level'),
        ),
      );
    });

    testWidgets('previous-on-first keeps its original error untouched', (tester) async {
      await tester.pumpWidget(
        _harness(
          frame: 0,
          child: MotionTarget(
            animations: [
              Animation.from(const Keyframe(opacity: 0), at: Trigger.previous),
            ],
            child: _square,
          ),
        ),
      );
      final error = tester.takeException();
      expect(
        error,
        isA<FluvieTimingError>().having(
          (e) => e.message,
          'message',
          contains('nothing to chain after'),
        ),
      );
      expect((error as FluvieTimingError).message, isNot(contains('composition level')));
    });
  });
}
