// The desktop preview clip path against real ffmpeg. Tagged `ffmpeg` (a local
// /usr/bin/ffmpeg is required) and excluded from the default run.
//
// This is the only test that builds PreviewMediaScope's *own* resolver from the
// platform provider instead of injecting a fake, so it is the only one that
// covers the desktop arm: the io provider streams clip frames through a disk
// store, and that window is filled solely by the capture loop's
// prepareClipFrames. A preview has no loop (its Ticker cannot await a decode),
// so the scope must select decode-all — without that, every clip paint throws
// "no clip frame N ... in the decode window". A fake resolver is decode-all and
// can never catch it.
@Tags(['ffmpeg'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';

/// The committed 320x240, 30fps, 1s test clip, relative to the repo root.
File _fixture() {
  for (final candidate in const [
    'examples/gallery/assets/fixtures/clip_1s.mp4',
    '../../examples/gallery/assets/fixtures/clip_1s.mp4',
  ]) {
    final file = File(candidate);
    if (file.existsSync()) return file.absolute;
  }
  fail('clip_1s.mp4 fixture not found (run from the repo root or packages/fluvie).');
}

void main() {
  testWidgets('a desktop preview decodes and paints a clip through ffmpeg', (tester) async {
    final controller = RenderController();
    addTearDown(controller.dispose);
    final video = Video(
      width: 320,
      height: 240,
      scenes: [
        Scene(
          duration: const Time.frames(4),
          children: [Clip.file(_fixture().path)],
        ),
      ],
    );

    Widget harness() => Directionality(
      textDirection: TextDirection.ltr,
      child: RenderControllerScope(
        controller: controller,
        child: Center(
          child: SizedBox(
            width: 320,
            height: 240,
            // No `resolver:` — this builds the real MediaRepository from the io
            // provider, which is the whole point of this test.
            child: PreviewMediaScope(composition: video, maxClipEdge: 160),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(harness());
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (find.byType(ImageResolverScope).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pumpWidget(harness());
      }
    });
    await tester.pump();

    expect(find.byType(ImageResolverScope), findsOneWidget, reason: 'the warm-up must have landed');
    final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
    expect(raw.image, isNotNull, reason: 'a streaming-mode miss would have thrown instead');
    // 320x240 bounded to a 160 long edge, through real ffmpeg scaling.
    expect(raw.image!.width, 160);
    expect(raw.image!.height, 120);
  });
}
