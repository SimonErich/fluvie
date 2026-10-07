import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';

import 'fakes/fake_media_resolver.dart';

const _source = MediaSource.asset('assets/cat/clip.mp4');

class _ReusableClip extends StatefulWidget {
  const _ReusableClip(this.onInit);
  final VoidCallback onInit;
  @override
  State<_ReusableClip> createState() => _ReusableClipState();
}

class _ReusableClipState extends State<_ReusableClip> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) => Clip.asset(
        'assets/cat/clip.mp4',
      ).animate([Animation.fadeIn(duration: 1.frames)]).show(from: 1.frames, to: 3.frames),
    ),
  );
}

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint()..color = const ui.Color(0xff00ff00));
  return recorder.endRecording().toImage(4, 4);
}

FakeMediaResolver _resolver(ui.Image image) => FakeMediaResolver(
  {_source: (bytes: Uint8List(0), contentHash: 'clip')},
  metadata: {_source: (fps: 30, frameCount: 10, width: 4, height: 4, hasAudio: true)},
  clipFrames: {
    _source: {for (var i = 0; i < 10; i++) i: image},
  },
);

Future<void> _prepare(
  WidgetTester tester,
  CompositionSession session,
  RenderController controller,
) async {
  Widget tree() => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 40,
      height: 40,
      child: buildCaptureShell(
        composition: session.mountTree(session.composition),
        boundaryKey: GlobalKey(),
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
  testWidgets(
    'normal reusable Flutter components in inactive scenes expose their actual timed clip window',
    (tester) async {
      final image = await _image();
      addTearDown(image.dispose);
      var initializations = 0;
      final video = Video(
        width: 40,
        height: 40,
        scenes: [
          Scene(duration: 4.frames),
          Scene(duration: 4.frames, children: [_ReusableClip(() => initializations++)]),
        ],
      );
      final session = CompositionSession(composition: video, resolver: _resolver(image));
      final controller = RenderController();
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      expect(() => session.prepared, throwsStateError);
      await _prepare(tester, session, controller);
      final prepared = session.prepared;
      expect(prepared.video, same(video));
      expect(prepared.clipPlans.single.windowStart, 5);
      expect(prepared.clipAudioPlans.single.startFrame, 5);
      expect(prepared.clipPlans.clear, throwsUnsupportedError);
      expect(initializations, 1);
      expect(session.clipPlans, hasLength(1));
      expect(session.clipPlans.single.windowStart, 5);
      expect(session.clipPlans.single.windowLength, 2);
      expect(session.clipAudioPlans.single.startFrame, 5);
      expect(session.clipAudioPlans.single.windowFrames, 2);
      await session.prepareFrame(5);
      controller.seek(5);
      await tester.pump();
      expect(initializations, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('explicit alternatives support a genuinely frame-dependent custom builder', (
    tester,
  ) async {
    final image = await _image();
    addTearDown(image.dispose);
    final video = Video(
      width: 40,
      height: 40,
      scenes: [
        Scene(
          duration: 4.frames,
          children: [
            FrameBuilder(
              (context) =>
                  context.frame == 0 ? const SizedBox.shrink() : Clip.asset('assets/cat/clip.mp4'),
              resources: const CompositionResources(clips: [ClipResource(source: _source)]),
            ),
          ],
        ),
      ],
    );
    final session = CompositionSession(composition: video, resolver: _resolver(image));
    final controller = RenderController();
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await _prepare(tester, session, controller);
    await session.prepareFrame(1);
    controller.seek(1);
    await tester.pump();
    expect(session.clipPlans.single.windowLength, 4);
    expect(tester.takeException(), isNull);
  });

  for (final useFlutterImage in [false, true]) {
    testWidgets('a declared late ${useFlutterImage ? 'Flutter' : 'Fluvie'} image is warm', (
      tester,
    ) async {
      final image = await _image();
      addTearDown(image.dispose);
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      ))!.buffer.asUint8List();
      final source = MediaSource.memory(bytes);
      final session = CompositionSession(
        composition: Video(
          width: 40,
          height: 40,
          scenes: [
            Scene(
              duration: 8.frames,
              children: [
                FrameBuilder(
                  (ctx) => ctx.frame > 5
                      ? useFlutterImage
                            ? flutter.Image.memory(bytes)
                            : Image.memory(bytes)
                      : const SizedBox.shrink(),
                  resources: CompositionResources(media: [source]),
                ),
              ],
            ),
          ],
        ),
        resolver: FakeMediaResolver(
          {source: (bytes: bytes, contentHash: 'image')},
          images: {source: image},
        ),
      );
      final controller = RenderController();
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      await _prepare(tester, session, controller);
      await session.prepareFrame(6);
      controller.seek(6);
      await tester.pump();
      session.validateFrameResources();
      expect(tester.takeException(), isNull);
      expect(find.byType(flutter.RawImage), findsOneWidget);
      expect(tester.widget<flutter.RawImage>(find.byType(flutter.RawImage)).image, isNotNull);
    });
  }

  testWidgets('an undeclared late image names its frame and declaration remedy', (tester) async {
    final image = await _image();
    addTearDown(image.dispose);
    final session = CompositionSession(
      composition: Video(
        width: 40,
        height: 40,
        scenes: [
          Scene(
            duration: 8.frames,
            children: [
              FrameBuilder(
                (ctx) =>
                    ctx.frame > 5 ? Image.asset('assets/cat/later.png') : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
      resolver: _resolver(image),
    );
    final controller = RenderController();
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await _prepare(tester, session, controller);
    await session.prepareFrame(6);
    controller.seek(6);
    await tester.pump();
    final error = tester.takeException();
    expect(error, isA<FluvieRenderException>());
    expect('$error', contains('frame 6'));
    expect('$error', contains('assets/cat/later.png'));
    expect('$error', contains('FrameBuilder(resources: CompositionResources'));
  });

  testWidgets('preparation validates mounted cross-element timing before activation', (
    tester,
  ) async {
    final image = await _image();
    addTearDown(image.dispose);
    final missing = Anchor('missing');
    final session = CompositionSession(
      composition: Video(
        width: 40,
        height: 40,
        scenes: [
          Scene(
            duration: 4.frames,
            children: [
              Builder(
                builder: (_) => const SizedBox().animate([
                  Animation.fadeIn(at: Trigger.whenEnds(missing)),
                ]),
              ),
            ],
          ),
        ],
      ),
      resolver: _resolver(image),
    );
    final controller = RenderController();
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    Object? error;
    try {
      await _prepare(tester, session, controller);
    } on FluvieTimingError catch (failure) {
      error = failure;
    }
    expect(error, isA<FluvieTimingError>());
    expect(session.preparing, isTrue);
    expect(tester.takeException(), isNull);
  });
}
