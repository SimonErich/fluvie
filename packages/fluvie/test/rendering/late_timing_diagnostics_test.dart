import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';

import 'fakes/fake_media_resolver.dart';

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

void main() {
  testWidgets('live preview forwards late timing diagnostics to its error owner', (tester) async {
    final owner = Anchor('preview-cat-title');
    final video = Video(
      width: 40,
      height: 40,
      scenes: [
        Scene(
          duration: 10.frames,
          children: [
            FrameBuilder(
              (ctx) => ctx.frame < 6
                  ? const SizedBox.shrink()
                  : const SizedBox().animate([
                      Animation.fadeIn(duration: 1.frames),
                    ], anchor: owner),
            ),
          ],
        ),
      ],
    );
    final controller = RenderController();
    final frames = ValueNotifier<int>(0);
    final errors = <Object>[];
    addTearDown(controller.dispose);
    addTearDown(frames.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RenderControllerScope(
          controller: controller,
          child: SizedBox(
            width: 40,
            height: 40,
            child: PreviewMediaScope(
              composition: video,
              resolver: FakeMediaResolver({}),
              frames: frames,
              onError: errors.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(errors, isEmpty);
    frames.value = 6;
    controller.seek(6);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(errors, hasLength(1));
    expect(
      errors.single,
      isA<FluvieTimingError>().having(
        (error) => error.message,
        'message',
        allOf(contains('frame 6'), contains('preview-cat-title'), contains('.show()')),
      ),
    );
  });

  testWidgets('a late timed branch reports its frame, owner and stable visibility alternative', (
    tester,
  ) async {
    final owner = Anchor('late-cat-title');
    final session = CompositionSession(
      composition: Video(
        width: 40,
        height: 40,
        scenes: [
          Scene(
            duration: 10.frames,
            children: [
              FrameBuilder(
                (ctx) => ctx.frame < 6
                    ? const SizedBox.shrink()
                    : const SizedBox().animate([
                        Animation.fadeIn(duration: 1.frames),
                      ], anchor: owner),
              ),
            ],
          ),
        ],
      ),
      resolver: FakeMediaResolver({}),
    );
    final controller = RenderController();
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await _prepare(tester, session, controller);
    await session.prepareFrame(6);
    controller.seek(6);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      session.validateFrameResources,
      throwsA(
        isA<FluvieTimingError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('frame 6'),
            contains('late-cat-title'),
            contains('.show()'),
          ),
        ),
      ),
    );
  });

  testWidgets('an unconditionally mounted timed alternative can reveal later', (tester) async {
    final session = CompositionSession(
      composition: Video(
        width: 40,
        height: 40,
        scenes: [
          Scene(
            duration: 10.frames,
            children: [
              const SizedBox().show(from: 6.frames, to: 10.frames).animate([
                Animation.fadeIn(duration: 1.frames),
              ]),
            ],
          ),
        ],
      ),
      resolver: FakeMediaResolver({}),
    );
    final controller = RenderController();
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await _prepare(tester, session, controller);
    await session.prepareFrame(6);
    controller.seek(6);
    await tester.pump();
    expect(session.validateFrameResources, returnsNormally);
    expect(tester.takeException(), isNull);
  });
}
