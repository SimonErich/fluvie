import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/transition_compositor.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

/// Mounts [video] under a frame clock positioned at [frame].
Widget _harness(Video video, {RenderController? controller, int frame = 0}) =>
    RenderControllerScope(
      controller: controller ?? RenderController(initialFrame: frame),
      child: video,
    );

void main() {
  group('Video.transition — the single-source offset math (WI-8, D3/D12)', () {
    test('an overlapping crossFade shortens the total and starts scene 2 early', () {
      final video = Video(
        transition: Transition.crossFade(0.5.seconds), // overlap defaults true
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 2.seconds),
        ],
      );
      // t = 15 frames; total = 120 - 15 = 105; scene 2 starts 15 early.
      expect(video.totalFrames, 105);
      expect(video.sceneStartFrames, [0, 45]);
    });

    test('a sequential (overlap:false) crossFade leaves starts and total intact', () {
      final video = Video(
        transition: Transition.crossFade(0.5.seconds, overlap: false),
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 2.seconds),
        ],
      );
      expect(video.totalFrames, 120);
      expect(video.sceneStartFrames, [0, 60]);
    });

    test('no transition is bit-identical to the plain running sums', () {
      final plain = Video(
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 30.frames),
          Scene(duration: 500.ms),
        ],
      );
      expect(plain.totalFrames, 60 + 30 + 15);
      expect(plain.sceneStartFrames, [0, 60, 90]);
    });
  });

  group('Video.transition — the mounted compositor (WI-8, D6)', () {
    testWidgets('mounts a TransitionCompositor whose offsets match the getters', (tester) async {
      final video = Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 2.seconds),
        ],
      );
      await tester.pumpWidget(_harness(video));
      final compositor = tester.widget<TransitionCompositor>(find.byType(TransitionCompositor));
      expect(compositor.offsets.startFrames, video.sceneStartFrames);
      expect(compositor.offsets.totalFrames, video.totalFrames);
      expect(compositor.sceneShells, hasLength(2));
    });

    testWidgets('both scenes paint during the crossFade window, incoming under the pose', (
      tester,
    ) async {
      final controller = RenderController(initialFrame: 45); // window [45, 60)
      final video = Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 2.seconds),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: controller));
      // Both scenes live (no Offstage) and a FadeBox carries the blend opacity.
      expect(find.byType(Scene, skipOffstage: false), findsNWidgets(2));
      final fade = tester.widget<FadeBox>(find.byType(FadeBox).last);
      expect(fade.opacity, greaterThan(0));
      expect(fade.opacity, lessThan(1));
    });

    testWidgets('a cut-only Video offstages scenes outside their window (SceneGate pins)', (
      tester,
    ) async {
      final controller = RenderController();
      final video = Video(
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 1.seconds),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: controller));

      List<bool> flags() => [
        for (final offstage in tester.widgetList<Offstage>(
          find.byType(Offstage, skipOffstage: false),
        ))
          offstage.offstage,
      ];
      expect(flags(), [false, true]); // scene 1 solo, scene 2 hidden

      controller.seek(60);
      await tester.pump();
      expect(flags(), [true, false]); // scene 1 hidden, scene 2 solo
    });
  });

  group('Video.transition — registrations survive boundary crossings (WI-8, D6)', () {
    testWidgets('per-scene GlobalKeys keep the second scene resolvable across the window', (
      tester,
    ) async {
      final controller = RenderController();
      final video = Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          Scene(duration: 2.seconds, children: const [SizedBox()]),
          Scene(duration: 2.seconds, children: const [SizedBox()]),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: controller));
      await tester.pump(); // let the post-frame resolve run

      // Pump across blendStart and blendEnd — no D3-P6 stable-set throw.
      for (final frame in [40, 45, 50, 59, 60, 70]) {
        controller.seek(frame);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Video.transition — didUpdateWidget re-resolves (WI-11, D12)', () {
    testWidgets('changing the transition re-collects and recomputes the totals', (tester) async {
      final controller = RenderController();
      // Two-scene videos; only the transition differs between pumps.
      final overlapping = Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          Scene(duration: 2.seconds, children: const [SizedBox()]),
          Scene(duration: 2.seconds, children: const [SizedBox()]),
        ],
      );
      final sequential = Video(
        transition: Transition.crossFade(0.5.seconds, overlap: false),
        scenes: overlapping.scenes,
      );

      await tester.pumpWidget(_harness(overlapping, controller: controller));
      await tester.pump();
      expect(
        tester.widget<TransitionCompositor>(find.byType(TransitionCompositor)).offsets.totalFrames,
        105,
      );

      await tester.pumpWidget(_harness(sequential, controller: controller));
      await tester.pump();
      expect(
        tester.widget<TransitionCompositor>(find.byType(TransitionCompositor)).offsets.totalFrames,
        120,
      );
    });
  });
}
