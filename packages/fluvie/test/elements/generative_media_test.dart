import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_generative_exception.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/elements/generative_media.dart';
import 'package:fluvie/src/elements/runtime/clip_painter.dart';
import 'package:fluvie/src/media/runtime/generative_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/resolved_image.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

import '../rendering/fakes/fake_generative_resolver.dart';
import '../rendering/fakes/fake_media_resolver.dart';

const _imageSource = GenerativeSource.image(providerId: 'flux', prompt: 'a cat');
const _videoSource = GenerativeSource.video(providerId: 'veo', prompt: 'a cat');
const _musicSource = GenerativeSource.music(providerId: 'suno', prompt: 'lofi');
const _file = MediaSource.file('/cache/x.png');
const _clipFile = MediaSource.file('/cache/x.mp4');

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF2ECC71),
  );
  return recorder.endRecording().toImage(4, 4);
}

void main() {
  test('generativeSource exposes the source for the collector', () {
    expect(const GenerativeMedia(source: _imageSource).generativeSource, _imageSource);
  });

  testWidgets('capture paints a sync RawImage from the produced media', (tester) async {
    final decoded = await _solidImage();
    addTearDown(decoded.dispose);
    const produced = MediaSource.asset('fixtures/swatch.png');
    final media = FakeMediaResolver(
      {produced: (bytes: Uint8List(0), contentHash: 'x')},
      images: {produced: decoded},
    );
    await media.preResolveAll([produced]);
    final gen = FakeGenerativeResolver(media: {_imageSource: produced});

    await tester.pumpWidget(
      ImageResolverScope(
        resolver: media,
        child: GenerativeResolverScope(
          resolver: gen,
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: GenerativeMedia(source: _imageSource, fit: BoxFit.contain),
          ),
        ),
      ),
    );

    final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
    expect(raw.image, same(decoded));
    expect(raw.fit, BoxFit.contain);
  });

  testWidgets('image source delegates to ResolvedImage', (tester) async {
    final gen = FakeGenerativeResolver(media: {_imageSource: _file});
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GenerativeResolverScope(
          resolver: gen,
          child: const GenerativeMedia(source: _imageSource),
        ),
      ),
    );
    expect(find.byType(ResolvedImage), findsOneWidget);
  });

  testWidgets('video source delegates to ClipPainter', (tester) async {
    final gen = FakeGenerativeResolver(media: {_videoSource: _clipFile});
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GenerativeResolverScope(
          resolver: gen,
          child: const GenerativeMedia(source: _videoSource),
        ),
      ),
    );
    expect(find.byType(ClipPainter), findsOneWidget);
  });

  testWidgets('an audio source throws FluvieGenerativeException', (tester) async {
    final gen = FakeGenerativeResolver();
    await tester.pumpWidget(
      GenerativeResolverScope(
        resolver: gen,
        child: const GenerativeMedia(source: _musicSource),
      ),
    );
    expect(tester.takeException(), isA<FluvieGenerativeException>());
  });

  testWidgets('capture without a resolver throws naming the source', (tester) async {
    await tester.pumpWidget(
      const RenderModeContext(
        mode: RenderMode.capture,
        child: GenerativeMedia(source: _imageSource),
      ),
    );
    final error = tester.takeException();
    expect(error, isA<FluvieGenerativeException>());
    expect((error as FluvieGenerativeException).message, contains('flux'));
  });

  testWidgets('preview without a resolver shows the placeholder', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GenerativeMedia(source: _imageSource, placeholder: Text('loading')),
      ),
    );
    expect(find.text('loading'), findsOneWidget);
  });
}
