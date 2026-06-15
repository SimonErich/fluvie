import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/scene.dart';

import 'package:fluvie/src/composition/transition/runtime/morph_layer.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_scope.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

const _box = ColoredBox(color: Color(0xFFE74C3C));

Widget _harness(Video video, {RenderController? controller, int frame = 0, TimelineProbe? probe}) {
  Widget tree = RenderControllerScope(
    controller: controller ?? RenderController(initialFrame: frame),
    child: video,
  );
  if (probe != null) tree = TimelineProbeScope(probe: probe, child: tree);
  return tree;
}

Scene _scene(Time duration, {Anchor? hero, Transition? enter}) => Scene(
  duration: duration,
  enter: enter,
  children: [
    if (hero != null) SharedElement(anchor: hero, child: _box) else _box,
  ],
);

void main() {
  group('VideoState hero wiring (WI-14, D10)', () {
    testWidgets('a valid pair across a crossFade boundary pumps clean', (tester) async {
      final logo = Anchor('logo');
      final video = Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          _scene(2.seconds, hero: logo),
          _scene(2.seconds, hero: logo),
        ],
      );
      await tester.pumpWidget(_harness(video));
      await tester.pump(); // run the post-frame resolve + validate
      expect(tester.takeException(), isNull);
    });

    testWidgets('a SharedElementScope is mounted per scene', (tester) async {
      final logo = Anchor('logo');
      final video = Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          _scene(2.seconds, hero: logo),
          _scene(2.seconds, hero: logo),
        ],
      );
      await tester.pumpWidget(_harness(video));
      final scopes = tester
          .widgetList<SharedElementScope>(find.byType(SharedElementScope, skipOffstage: false))
          .toList();
      expect(scopes, hasLength(2));
      expect(scopes.map((s) => s.sceneIndex).toList()..sort(), [0, 1]);
      // One registry shared across both scopes.
      expect(identical(scopes[0].registry, scopes[1].registry), isTrue);
    });

    testWidgets('a missing pair reports the D10 error via the probe', (tester) async {
      final logo = Anchor('logo');
      final video = Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          _scene(2.seconds, hero: logo), // only scene 0 has the hero
          _scene(2.seconds),
        ],
      );
      final probe = TimelineProbe();
      addTearDown(probe.dispose);
      await tester.pumpWidget(_harness(video, probe: probe));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(probe.timingError, isNotNull);
      expect(probe.timingError, contains('one scene'));
    });

    testWidgets('a three-scene anchor reports an error naming all three', (tester) async {
      final logo = Anchor('logo');
      final video = Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          _scene(2.seconds, hero: logo),
          _scene(2.seconds, hero: logo),
          _scene(2.seconds, hero: logo),
        ],
      );
      final probe = TimelineProbe();
      addTearDown(probe.dispose);
      await tester.pumpWidget(_harness(video, probe: probe));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        probe.timingError,
        allOf(contains('scenes[0]'), contains('scenes[1]'), contains('scenes[2]')),
      );
    });

    testWidgets('a pair across a cut boundary is inert (validates, no morph)', (tester) async {
      final logo = Anchor('logo');
      final video = Video(
        // No video default and no enter/exit: boundary 0 is a cut.
        scenes: [
          _scene(2.seconds, hero: logo),
          _scene(2.seconds, hero: logo),
        ],
      );
      await tester.pumpWidget(_harness(video));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a morph mounts during the blend window, gone outside it', (tester) async {
      final logo = Anchor('logo');
      final controller = RenderController(); // frame 0: pre-window
      final video = Video(
        // 2s + 2s scenes, 0.5s overlap crossFade: window [45, 60).
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          _scene(2.seconds, hero: logo),
          _scene(2.seconds, hero: logo),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: controller));
      await tester.pump(); // resolve + validate
      expect(find.byType(MorphLayer), findsNothing); // no window at frame 0

      controller.seek(49); // mid-window
      await tester.pump();
      expect(find.byType(MorphLayer), findsOneWidget);

      controller.seek(70); // scene 2 solo
      await tester.pump();
      expect(find.byType(MorphLayer), findsNothing);
    });

    testWidgets('changing the scenes resets the registry (no stale-set throw)', (tester) async {
      final logoA = Anchor('logoA');
      Video build(Anchor hero) => Video(
        transition: Transition.crossFade(0.5.seconds),
        scenes: [
          _scene(2.seconds, hero: hero),
          _scene(2.seconds, hero: hero),
        ],
      );
      await tester.pumpWidget(_harness(build(logoA)));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // A different scenes list with a fresh anchor must re-collect cleanly.
      final logoB = Anchor('logoB');
      await tester.pumpWidget(_harness(build(logoB)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
