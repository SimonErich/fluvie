import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import '../../rendering/fakes/fake_media_resolver.dart';
import '../../serialization/element_transition_spec_test.dart' show deck;

Future<ui.Image> swatch(ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 160, 90), ui.Paint()..color = color);
  return recorder.endRecording().toImage(160, 90);
}

void main() {
  testWidgets('clip dissolve paints both sources and keeps child state across every boundary', (
    tester,
  ) async {
    final red = await tester.runAsync(() => swatch(const ui.Color(0xffff0000)));
    final blue = await tester.runAsync(() => swatch(const ui.Color(0xff0000ff)));
    const a = MediaSource.asset('a.mp4');
    const b = MediaSource.asset('b.mp4');
    final resolver = FakeMediaResolver(
      {a: (bytes: Uint8List(0), contentHash: 'a'), b: (bytes: Uint8List(0), contentHash: 'b')},
      metadata: {
        for (final source in [a, b])
          source: (fps: 30, frameCount: 120, width: 160, height: 90, hasAudio: true),
      },
      clipFrames: {
        a: {for (var i = 0; i < 120; i++) i: red!},
        b: {for (var i = 0; i < 120; i++) i: blue!},
      },
    );
    await resolver.preResolveClip(a, [for (var i = 0; i < 120; i++) i]);
    await resolver.preResolveClip(b, [for (var i = 0; i < 120; i++) i]);
    final controller = RenderController(initialFrame: 49);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 160,
            height: 90,
            child: RepaintBoundary(
              key: boundary,
              child: ImageResolverScope(
                resolver: resolver,
                child: RenderControllerScope(
                  controller: controller,
                  child: VideoSpec.fromJson(deck()).build(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 49; frame <= 61; frame++) {
      controller.seek(frame);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'frame $frame');
      if (frame != 54) continue;
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/element_transition_mid.png'),
      );
      final image = await tester.runAsync(
        () => (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(),
      );
      final bytes = await tester.runAsync(
        () => image!.toByteData(),
      );
      final offset = (45 * image!.width + 80) * 4;
      expect(bytes!.getUint8(offset), closeTo(128, 2));
      expect(bytes.getUint8(offset + 2), closeTo(128, 2));
      image.dispose();
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    red!.dispose();
    blue!.dispose();
  });
}
