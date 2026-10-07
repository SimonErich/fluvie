// Overlays: elements that belong to no scene. One instance for the whole
// video, mounted once, never re-parented across a boundary, on the video's
// own clock.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/composition/runtime/overlay_layer.dart';
import 'package:fluvie/src/composition/runtime/transition_compositor.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar_scope.dart';

/// A widget that counts how many times its State was created, so a test can
/// prove one instance survived every boundary rather than being rebuilt.
final class _Counted extends StatefulWidget {
  const _Counted({required this.tally, super.key});
  final List<int> tally;

  @override
  State<_Counted> createState() => _CountedState();
}

final class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.tally.add(1);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Video _video({List<Widget> overlays = const [], Transition? transition}) => Video(
  width: 320,
  height: 180,
  transition: transition,
  overlays: overlays,
  scenes: const [
    Scene(duration: Time.frames(30), children: [Text('one')]),
    Scene(duration: Time.frames(30), children: [Text('two')]),
    Scene(duration: Time.frames(30), children: [Text('three')]),
  ],
);

Future<RenderController> _pump(WidgetTester tester, Video video, {int frame = 0}) async {
  final controller = RenderController(initialFrame: frame);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RenderControllerScope(controller: controller, child: video),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  group('the layer', () {
    testWidgets('is not mounted at all by a video with no overlays', (tester) async {
      // The mounted tree of every video that existed before overlays did is
      // exactly what it was.
      await _pump(tester, _video());

      expect(find.byType(OverlayLayer), findsNothing);
    });

    testWidgets('is mounted by a video that declares one', (tester) async {
      await _pump(tester, _video(overlays: const [Text('logo')]));

      expect(find.byType(OverlayLayer), findsOneWidget);
      expect(find.text('logo'), findsOneWidget);
    });

    testWidgets('paints above the composition', (tester) async {
      await _pump(tester, _video(overlays: const [Text('logo')]));

      final stack = tester.widget<Stack>(
        find.ancestor(of: find.byType(OverlayLayer), matching: find.byType(Stack)).first,
      );

      expect(stack.children.first, isA<TransitionCompositor>());
      expect(stack.children.last, isA<CompositionRegistrarScope>());
      expect(stack.fit, StackFit.passthrough, reason: 'the composition keeps its constraints');
    });

    testWidgets('paints its own overlays in declaration order, last on top', (tester) async {
      await _pump(tester, _video(overlays: const [Text('under'), Text('over')]));

      final layer = tester.widget<OverlayLayer>(find.byType(OverlayLayer));

      expect((layer.overlays.last as Text).data, 'over');
    });
  });

  group('the video it sits on', () {
    test('is not lengthened by an overlay', () {
      // An overlay takes no part in the offset math: it sits on the video, it
      // does not extend it.
      final plain = _video();
      final withOverlay = _video(overlays: const [Text('logo')]);

      expect(withOverlay.totalFrames, plain.totalFrames);
      expect(withOverlay.sceneStartFrames, plain.sceneStartFrames);
    });

    test('keeps its boundaries where they were, transitions and all', () {
      final plain = _video(transition: const Transition.crossFade(Time.frames(10)));
      final withOverlay = _video(
        transition: const Transition.crossFade(Time.frames(10)),
        overlays: const [Text('logo')],
      );

      expect(withOverlay.sceneStartFrames, plain.sceneStartFrames);
      expect(withOverlay.totalFrames, plain.totalFrames);
    });
  });

  group('one instance', () {
    testWidgets('survives every boundary crossing', (tester) async {
      // The whole point of an overlay, and the one thing a scene-paired morph
      // can never be: the same State object from the first frame to the last.
      final tally = <int>[];
      final controller = await _pump(
        tester,
        _video(
          transition: const Transition.crossFade(Time.frames(10)),
          overlays: [_Counted(tally: tally, key: const ValueKey('logo'))],
        ),
      );

      final state = tester.state<_CountedState>(find.byType(_Counted));
      // Walk the whole video, boundaries and blends included.
      for (var frame = 0; frame <= 80; frame += 4) {
        controller.seek(frame);
        await tester.pump();
      }

      expect(tally, hasLength(1), reason: 'mounted once, for the whole video');
      expect(tester.state<_CountedState>(find.byType(_Counted)), same(state));
    });
  });

  group('the timeline it resolves into', () {
    testWidgets('is the whole video, and an overlay never lengthens it', (tester) async {
      // 90 frames in three 30-frame scenes, with an overlay windowed 10..80 —
      // a span no scene child could even name.
      final probe = TimelineProbe();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RenderControllerScope(
            controller: RenderController(),
            child: TimelineProbeScope(
              probe: probe,
              child: Video(
                width: 320,
                height: 180,
                overlays: [
                  const Text('logo').show(from: const Time.frames(10), to: const Time.frames(80)),
                ],
                scenes: const [
                  Scene(duration: Time.frames(30), children: [Text('one')]),
                  Scene(duration: Time.frames(30), children: [Text('two')]),
                  Scene(duration: Time.frames(30), children: [Text('three')]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(probe.value, isNotNull);
      expect(probe.value!.totalFrames, 90);
      expect(probe.timingError, isNull);
    });
  });

  group('how an overlay lays out', () {
    testWidgets('exactly like a scene child: loose constraints, centred', (tester) async {
      // Moving an element from a scene into the overlays must not change where
      // it is or how big it is. Forwarding the canvas-tight constraints would
      // stretch it to the full frame and pin it top-left.
      await _pump(
        tester,
        Video(
          width: 320,
          height: 180,
          overlays: const [Text('same', key: ValueKey('overlay'))],
          scenes: const [
            Scene(
              duration: Time.frames(30),
              children: [Text('same', key: ValueKey('scene'))],
            ),
          ],
        ),
      );

      final scened = tester.getRect(find.byKey(const ValueKey('scene')));
      final overlaid = tester.getRect(find.byKey(const ValueKey('overlay')));

      expect(overlaid.size, scened.size, reason: 'an overlay sizes itself');
      expect(overlaid.center, scened.center, reason: 'and centres like a child');
    });
  });
}
