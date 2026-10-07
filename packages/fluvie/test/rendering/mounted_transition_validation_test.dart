import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';

import 'fakes/fake_media_resolver.dart';

const _source = MediaSource.asset('cat.mp4');

Future<FakeMediaResolver> _resolver() async {
  final picture = ui.PictureRecorder();
  ui.Canvas(picture).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xff009988),
  );
  final image = await picture.endRecording().toImage(4, 4);
  addTearDown(image.dispose);
  return FakeMediaResolver(
    {_source: (bytes: Uint8List(0), contentHash: 'cat')},
    metadata: {_source: (fps: 30, frameCount: 20, width: 4, height: 4, hasAudio: false)},
    clipFrames: {
      _source: {for (var frame = 0; frame < 20; frame++) frame: image},
    },
  );
}

Future<void> _prepare(
  WidgetTester tester,
  CompositionSession session,
  RenderController controller,
) async {
  final boundary = GlobalKey();
  Widget tree() => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 40,
      height: 40,
      child: buildCaptureShell(
        composition: session.mountTree(session.composition),
        boundaryKey: boundary,
        controller: controller,
      ).tree,
    ),
  );
  await session.prepare(
    mount: tester.pumpWidget,
    pump: () => tester.pump(),
    buildTree: tree,
    runAsync: tester.runAsync,
  );
}

Video _transitionVideo(Widget outgoing) => Video(
  width: 40,
  height: 40,
  scenes: [
    Scene(
      duration: 16.frames,
      children: [
        ClipTransitionGroup(
          transitions: [
            ClipTransition(
              outgoing: 'cat-before',
              incoming: 'cat-after',
              transition: Transition.crossFade(4.frames),
            ),
          ],
          children: [
            ElementId(
              id: 'cat-before',
              lane: 'cat',
              child: outgoing.show(from: 0.frames, to: 8.frames),
            ),
            ElementId(
              id: 'cat-after',
              lane: 'cat',
              child: Clip.asset('cat.mp4').show(from: 8.frames, to: 16.frames),
            ),
            Builder(builder: (_) => const Text('An unrelated overlay')),
          ],
        ),
      ],
    ),
  ],
);

Future<FluvieTimingError?> _preparationFailure(
  WidgetTester tester,
  CompositionSession session,
  RenderController controller,
) async {
  try {
    await _prepare(tester, session, controller);
    return null;
  } on FluvieTimingError catch (error) {
    return error;
  }
}

void main() {
  for (final target in <Widget>[const Text('not footage'), const SizedBox.shrink()]) {
    testWidgets('an opaque ${target.runtimeType} is rejected as a clip transition target', (
      tester,
    ) async {
      final session = CompositionSession(
        composition: _transitionVideo(target),
        resolver: await _resolver(),
      );
      final controller = RenderController();
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      expect(
        await _preparationFailure(tester, session, controller),
        isA<FluvieTimingError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('ClipTransitionGroup'),
            contains('cat-before'),
            contains('Clip'),
          ),
        ),
      );
      expect(session.preparing, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a real clip inside ordinary builders remains eligible', (tester) async {
    final session = CompositionSession(
      composition: _transitionVideo(Builder(builder: (_) => Clip.asset('cat.mp4'))),
      resolver: await _resolver(),
    );
    final controller = RenderController();
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await _prepare(tester, session, controller);
    expect(session.preparing, isFalse);
    expect(session.prepared.clipPlans, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  for (final wrapShared in [false, true]) {
    testWidgets(
      'a hidden ${wrapShared ? 'SharedElement' : 'Clip.shared'} names the target and remedy',
      (tester) async {
        final hero = Anchor('cat-hero');
        final session = CompositionSession(
          composition: _transitionVideo(
            Builder(
              builder: (_) => wrapShared
                  ? SharedElement(anchor: hero, child: Clip.asset('cat.mp4'))
                  : Clip.asset('cat.mp4', shared: hero),
            ),
          ),
          resolver: await _resolver(),
        );
        final controller = RenderController();
        addTearDown(controller.dispose);
        addTearDown(session.dispose);
        expect(
          await _preparationFailure(tester, session, controller),
          isA<FluvieTimingError>()
              .having(
                (error) => error.message,
                'message',
                allOf(
                  contains('cat-before'),
                  contains('shared'),
                  contains('independent'),
                ),
              )
              .having((error) => error.anchors, 'anchors', contains(hero)),
        );
        expect(session.preparing, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
