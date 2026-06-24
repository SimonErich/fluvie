// End-to-end proof that the generative seam wires through a real render: the
// orchestrator runs generateAll before media pre-resolution, the generated
// source folds in as a file/asset-backed MediaSource, the capture shell mounts
// both the GenerativeResolverScope and the ImageResolverScope, and the generic
// GenerativeMedia paints the produced image into the captured frame.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart' show GenerativeProgress;
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/generative_media.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/render_aspect.dart';
import 'package:fluvie/src/rendering/render_service.dart';

import 'fakes/fake_generative_resolver.dart';
import 'fakes/fake_media_resolver.dart';

const _img = GenerativeSource.image(providerId: 'flux', prompt: 'a green square');
const _produced = MediaSource.asset('generated/green.png');

Future<ui.Image> _solidGreen() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  return recorder.endRecording().toImage(4, 4);
}

void main() {
  testWidgets('render() generates, folds, decodes, and paints a generated image', (tester) async {
    final decoded = await _solidGreen();
    addTearDown(decoded.dispose);

    // The media resolver only knows the *produced* asset; the generative
    // resolver maps the GenerativeSource to it. So the frame can only be green if
    // generation ran and folded the produced source into the media pre-pass.
    final media = FakeMediaResolver(
      {_produced: (bytes: Uint8List(0), contentHash: 'x')},
      images: {_produced: decoded},
    );
    final generative = FakeGenerativeResolver(media: {_img: _produced});

    final video = Video(
      width: 16,
      height: 16,
      scenes: const [
        Scene(
          duration: Time.frames(2),
          children: [
            SizedBox.expand(
              child: GenerativeMedia(source: _img, fit: BoxFit.fill),
            ),
          ],
        ),
      ],
    );

    tester.view.physicalSize = const ui.Size(16, 16);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('fluvie_gen_e2e_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final progress = <GenerativeProgress>[];

    await tester.runAsync(() async {
      await render(
        composition: video,
        aspect: Aspect.square,
        longEdge: 16,
        frameCount: 2,
        outDir: dir,
        service: RenderService(capture: const RepaintBoundaryCaptureService(), media: media),
        pumpWidget: tester.pumpWidget,
        pumpFrame: () => tester.pump(),
        resolver: media,
        generative: generative,
        onGenerativeProgress: progress.add,
      );
    });

    // generateAll ran for the declared source, before the media pre-pass.
    expect(generative.generated, [_img]);
    // Generation progress is surfaced to the caller.
    expect(progress.map((p) => p.providerId), contains('flux'));
    // The captured top-left pixel is the produced image's green (RGBA).
    final frames = File('${dir.path}/frames.rgba').readAsBytesSync();
    expect(frames.sublist(0, 4), const [0x00, 0xFF, 0x00, 0xFF]);
  });
}
