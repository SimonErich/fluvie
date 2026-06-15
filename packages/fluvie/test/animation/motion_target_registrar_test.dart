import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/runtime/video_plan_builder.dart';
import 'package:fluvie/src/composition/runtime/video_registrar.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar_scope.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/schedule/resolved_schedule_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _squareKey = Key('square');
const _square = SizedBox(key: _squareKey, width: 20, height: 20);

Animation _fade({Time duration = const Time.frames(20)}) =>
    Animation.from(const Keyframe(opacity: 0), duration: duration, ease: Ease.linear);

/// Mounts [child] under the full frame + timing + registrar harness:
/// a 60-frame, 30 fps video with one whole-length scene.
Widget _harness({
  required RenderController controller,
  required CompositionRegistrar registrar,
  required Widget child,
}) => RenderControllerScope(
  controller: controller,
  child: VideoScope(
    fps: 30,
    duration: const Time.frames(60),
    child: SceneScope(
      duration: const Time.frames(60),
      child: CompositionRegistrarScope(registrar: registrar, child: child),
    ),
  ),
);

double _opacityOf(WidgetTester tester, Key key) => tester
    .widget<Opacity>(find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first)
    .opacity;

void main() {
  group('MotionTarget under a registrar — the collect pass (D1/D3)', () {
    testWidgets('pass 1 renders the child hidden with its layout slot held', (tester) async {
      final registrar = VideoRegistrar(sceneCount: 1);
      final controller = RenderController(initialFrame: 10);
      await tester.pumpWidget(
        _harness(
          controller: controller,
          registrar: registrar.forScene(0),
          child: Center(
            child: MotionTarget(animations: [_fade()], child: _square),
          ),
        ),
      );
      // Local resolution would show 0.5 at frame 10; the placeholder is 0.
      expect(_opacityOf(tester, _squareKey), 0.0);
      expect(tester.getSize(find.byKey(_squareKey)), const Size(20, 20));
      expect(registrar.registrationsByScene[0], hasLength(1));
    });

    testWidgets('the registration token carries the converted plans and fields', (tester) async {
      final registrar = VideoRegistrar(sceneCount: 1);
      final anchor = Anchor('bg');
      final window = 10.frames.to(40.frames);
      const defaults = Defaults(duration: Time.frames(5));
      await tester.pumpWidget(
        _harness(
          controller: RenderController(),
          registrar: registrar.forScene(0),
          child: MotionTarget(
            animations: [_fade()],
            anchor: anchor,
            window: window,
            defaults: defaults,
            child: _square,
          ),
        ),
      );
      final token = registrar.registrationsByScene[0].single;
      expect(token.debugOwner, 'bg');
      expect(token.anchor, same(anchor));
      expect(token.window, same(window));
      expect(token.animations, hasLength(1));
      expect(token.defaults, defaults);
    });
  });

  group('MotionTarget under a registrar — the resolved pass (D1/D4)', () {
    testWidgets('after resolution the injected spans drive the opacity', (tester) async {
      final registrar = VideoRegistrar(sceneCount: 1);
      final controller = RenderController(initialFrame: 20);
      // The same widget instance across pumps: rebuilds ride the scope.
      final target = MotionTarget(animations: [_fade()], child: _square);
      await tester.pumpWidget(
        _harness(controller: controller, registrar: registrar.forScene(0), child: target),
      );
      // Locally the fade would resolve to 0..20 (1.0 at frame 20); inject a
      // shifted span 10..30 so frame 20 sits at exactly 0.5 — the injected
      // schedule is provably the one consumed.
      final token = registrar.registrationsByScene[0].single;
      registrar.resolveWith({
        token: const ElementSchedule(
          window: ResolvedSpan(0, 60),
          spans: [ResolvedSpan(10, 30)],
          defaults: Defaults(duration: Time.frames(20), ease: Ease.linear),
        ),
      });
      await tester.pumpWidget(
        _harness(controller: controller, registrar: registrar.forScene(0), child: target),
      );
      expect(_opacityOf(tester, _squareKey), closeTo(0.5, 1e-9));
    });

    testWidgets('an explicit ResolvedScheduleScope beats the registrar (D4)', (tester) async {
      final registrar = VideoRegistrar(sceneCount: 1);
      const injected = ElementSchedule(
        window: ResolvedSpan(0, 60),
        spans: [ResolvedSpan(10, 30)],
        defaults: Defaults(duration: Time.frames(20), ease: Ease.linear),
      );
      await tester.pumpWidget(
        _harness(
          controller: RenderController(initialFrame: 10),
          registrar: registrar.forScene(0),
          child: ResolvedScheduleScope(
            schedule: injected,
            child: MotionTarget(animations: [_fade()], child: _square),
          ),
        ),
      );
      // The injected span starts at frame 10 (opacity 0); the registrar was
      // never consulted, so nothing registered.
      expect(_opacityOf(tester, _squareKey), 0.0);
      expect(registrar.registrationsByScene[0], isEmpty);
    });

    testWidgets('no registrar: the local fallback is unchanged (D4)', (tester) async {
      await tester.pumpWidget(
        RenderControllerScope(
          controller: RenderController(initialFrame: 10),
          child: VideoScope(
            fps: 30,
            duration: const Time.frames(60),
            child: SceneScope(
              duration: const Time.frames(60),
              child: MotionTarget(animations: [_fade()], child: _square),
            ),
          ),
        ),
      );
      expect(_opacityOf(tester, _squareKey), closeTo(0.5, 1e-9));
    });
  });

  group('MotionTarget under a registrar — window inheritance (D22)', () {
    testWidgets('a nested animated target inherits the enclosing shown window', (tester) async {
      // In tree order the windowed target must enclose the animated one:
      // `.animate(...).show(...)` — the show shell wraps the animation.
      final registrar = VideoRegistrar(sceneCount: 1);
      final controller = RenderController();
      final stacked = _square.animate([_fade()]).show(from: 30.frames, to: 60.frames);
      await tester.pumpWidget(
        _harness(controller: controller, registrar: registrar.forScene(0), child: stacked),
      );
      final tokens = registrar.registrationsByScene[0];
      expect(tokens, hasLength(2));
      expect(tokens[0].debugOwner, 'MotionTarget'); // The outer show shell.
      expect(tokens[1].debugOwner, 'SizedBox'); // The inner animated target.
      expect(tokens[1].window, same(tokens[0].window));

      // Resolve for real: the fade places inside the shown window 30..60.
      final result = buildVideoPlan(
        fps: 30,
        scenes: [(duration: const Time.frames(60), defaults: null)],
        registrationsByScene: registrar.registrationsByScene,
      );
      expect(result.schedules[tokens[1]]!.window, const ResolvedSpan(30, 60));
      expect(result.schedules[tokens[1]]!.spans, [const ResolvedSpan(30, 50)]);

      registrar.resolveWith(result.schedules);
      await tester.pumpWidget(
        _harness(controller: controller, registrar: registrar.forScene(0), child: stacked),
      );
      controller.seek(40);
      await tester.pump();
      expect(_opacityOf(tester, _squareKey), closeTo(0.5, 1e-9));
    });
  });

  group('MotionTarget under a registrar — the stable-set contract (D3)', () {
    testWidgets('a new MotionTarget after resolution throws the D3 error', (tester) async {
      final registrar = VideoRegistrar(sceneCount: 1)..resolveWith(const {});
      await tester.pumpWidget(
        _harness(
          controller: RenderController(),
          registrar: registrar.forScene(0),
          child: MotionTarget(animations: [_fade()], child: _square),
        ),
      );
      expect(
        tester.takeException(),
        isA<FluvieTimingError>().having(
          (e) => e.message,
          'message',
          contains('stable across frames'),
        ),
      );
    });

    testWidgets('a timing-relevant field change after resolution throws', (tester) async {
      final registrar = VideoRegistrar(sceneCount: 1);
      final controller = RenderController();
      final animations = [_fade()];
      await tester.pumpWidget(
        _harness(
          controller: controller,
          registrar: registrar.forScene(0),
          child: MotionTarget(animations: animations, child: _square),
        ),
      );
      final token = registrar.registrationsByScene[0].single;
      registrar.resolveWith({
        token: const ElementSchedule(
          window: ResolvedSpan(0, 60),
          spans: [ResolvedSpan(0, 20)],
          defaults: Defaults(duration: Time.frames(20), ease: Ease.linear),
        ),
      });
      await tester.pumpWidget(
        _harness(
          controller: controller,
          registrar: registrar.forScene(0),
          child: MotionTarget(
            animations: animations,
            window: 10.frames.to(50.frames), // Changed after resolution.
            child: _square,
          ),
        ),
      );
      expect(
        tester.takeException(),
        isA<FluvieTimingError>().having(
          (e) => e.message,
          'message',
          contains('identical input every frame'),
        ),
      );
    });

    testWidgets('a timing-relevant field change during collect rebuilds the token', (
      tester,
    ) async {
      final registrar = VideoRegistrar(sceneCount: 1);
      final controller = RenderController();
      final animations = [_fade()];
      await tester.pumpWidget(
        _harness(
          controller: controller,
          registrar: registrar.forScene(0),
          child: MotionTarget(animations: animations, child: _square),
        ),
      );
      final window = 10.frames.to(50.frames);
      await tester.pumpWidget(
        _harness(
          controller: controller,
          registrar: registrar.forScene(0),
          child: MotionTarget(animations: animations, window: window, child: _square),
        ),
      );
      expect(tester.takeException(), isNull);
      final tokens = registrar.registrationsByScene[0];
      expect(tokens, hasLength(1));
      expect(tokens.single.window, same(window));
    });

    testWidgets('unmounting unregisters the token', (tester) async {
      final registrar = VideoRegistrar(sceneCount: 1);
      final controller = RenderController();
      await tester.pumpWidget(
        _harness(
          controller: controller,
          registrar: registrar.forScene(0),
          child: MotionTarget(animations: [_fade()], child: _square),
        ),
      );
      expect(registrar.registrationsByScene[0], hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(registrar.registrationsByScene[0], isEmpty);
    });
  });

  group('MotionTarget inside Video — cross-element triggers (D1/D15)', () {
    testWidgets('a cross-element trigger inside Video no longer throws', (tester) async {
      final bg = Anchor('bg');
      final controller = RenderController();
      await tester.pumpWidget(
        RenderControllerScope(
          controller: controller,
          child: Video(
            width: 320,
            height: 240,
            scenes: [
              Scene(
                duration: 60.frames,
                children: [
                  const SizedBox(width: 20, height: 20).animate([
                    _fade(duration: const Time.frames(30)),
                  ], anchor: bg),
                  _square.animate([
                    Animation.from(
                      const Keyframe(opacity: 0),
                      duration: const Time.frames(20),
                      ease: Ease.linear,
                      at: Trigger.after(bg),
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pump(); // The post-frame resolve's setState.
      expect(tester.takeException(), isNull);
      // The follower waits for the anchor: at frame 40 it sits mid-fade.
      controller.seek(40);
      await tester.pump();
      expect(_opacityOf(tester, _squareKey), closeTo(0.5, 1e-9));
    });
  });
}
