import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

import '../../rendering/fakes/fake_media_resolver.dart';

const _swatch = MediaSource.asset('bg.jpg');
const _movie = MediaSource.asset('bg.mp4');

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF2ECC71),
  );
  return recorder.endRecording().toImage(4, 4);
}

FakeMediaResolver _resolverWith(ui.Image image) =>
    FakeMediaResolver({_swatch: (bytes: Uint8List(0), contentHash: 'x')}, images: {_swatch: image});

/// A resolver that serves [frames] as clip frames of [_movie] (the clip path),
/// not as an image — the same shape `Clip` resolves against.
Future<FakeMediaResolver> _clipResolver(Map<int, ui.Image> frames) async {
  final resolver = FakeMediaResolver(
    const {},
    metadata: {_movie: (fps: 30, frameCount: 30, width: 4, height: 4, hasAudio: false)},
    clipFrames: {_movie: frames},
  );
  await resolver.preResolveClip(_movie, frames.keys);
  return resolver;
}

/// Wraps [background] in the time/frame scopes `ClipPainter` reads, in capture.
Widget _clipHarness({required Widget background, required MediaResolver resolver, int frame = 0}) {
  return ImageResolverScope(
    resolver: resolver,
    child: SizedBox(
      width: 80,
      height: 80,
      child: FrameProvider(
        frame: frame,
        child: VideoScope(
          fps: 30,
          duration: const Time.frames(30),
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: SceneScope(duration: const Time.frames(30), child: background),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Background.image (WI-8, D2/D4 — render path live)', () {
    testWidgets('paints a sync RawImage under a pre-resolving scope', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      final resolver = _resolverWith(image);
      await resolver.preResolveAll([_swatch]);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: Background.image('bg.jpg', fit: BoxFit.contain),
        ),
      );

      final rawImage = tester.widget<RawImage>(
        find.descendant(of: find.byType(Background), matching: find.byType(RawImage)),
      );
      expect(rawImage.image, same(image));
      expect(rawImage.fit, BoxFit.contain);
    });

    testWidgets('capture without resolution throws a typed error naming the source', (
      tester,
    ) async {
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: Background.image('bg.jpg'),
        ),
      );
      expect(
        tester.takeException(),
        isA<FluvieRenderException>().having((e) => e.message, 'message', contains('bg.jpg')),
      );
    });

    testWidgets('preview without a scope does not throw the capture error', (tester) async {
      await tester.pumpWidget(Background.image('bg.jpg'));
      // The async asset path may surface its own load failure, but never the
      // capture-without-resolution FluvieRenderException.
      final error = tester.takeException();
      expect(error, isNot(isA<FluvieRenderException>()));
    });
  });

  group('Background.video (WI-8, D2/D4/D7 — the real clip path)', () {
    testWidgets('paints the resampled clip frame as a sync RawImage', (tester) async {
      final f0 = await _solidImage();
      addTearDown(f0.dispose);
      final resolver = await _clipResolver({0: f0});

      await tester.pumpWidget(
        _clipHarness(background: Background.video('bg.mp4'), resolver: resolver),
      );

      final rawImage = tester.widget<RawImage>(
        find.descendant(of: find.byType(Background), matching: find.byType(RawImage)),
      );
      expect(rawImage.image, same(f0));
      expect(rawImage.fit, BoxFit.cover);
    });

    testWidgets('a later composition frame reads a later source frame', (tester) async {
      final f0 = await _solidImage();
      final f10 = await _solidImage();
      addTearDown(f0.dispose);
      addTearDown(f10.dispose);
      final resolver = await _clipResolver({0: f0, 10: f10});

      await tester.pumpWidget(
        _clipHarness(background: Background.video('bg.mp4'), resolver: resolver, frame: 10),
      );

      final rawImage = tester.widget<RawImage>(
        find.descendant(of: find.byType(Background), matching: find.byType(RawImage)),
      );
      expect(rawImage.image, same(f10));
    });

    testWidgets('capture without resolution throws a typed error naming the source', (
      tester,
    ) async {
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: Background.video('bg.mp4'),
        ),
      );
      expect(
        tester.takeException(),
        isA<FluvieRenderException>().having((e) => e.message, 'message', contains('bg.mp4')),
      );
    });
  });
}
