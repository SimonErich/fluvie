// Epic 8.1 background-media golden (WI-8): Background.image painting a
// pre-resolved swatch through the live render path (decision D2/D4). The image
// is a tiny solid square decoded in `main`, pre-resolved through a
// FakeMediaResolver and carried down by an ImageResolverScope, so the golden
// is font-free and byte-stable.
@Tags(['golden'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';

import '../animation/helpers/golden_frame.dart';
import '../rendering/fakes/fake_media_resolver.dart';

const _swatch = MediaSource.asset('fixtures/swatch.png');
const _canvas = Size(160, 284);

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0xFF8E44AD),
  );
  return recorder.endRecording().toImage(8, 8);
}

Future<void> main() async {
  final image = await _solidImage();
  final resolver = FakeMediaResolver(
    {_swatch: (bytes: Uint8List(0), contentHash: 'x')},
    images: {_swatch: image},
  );
  await resolver.preResolveAll([_swatch]);

  await goldenMotionVariants(
    description: 'Background.image: a pre-resolved swatch filling the canvas (cover)',
    fileName: 'background_image',
    frame: 0,
    size: _canvas,
    variants: [
      (
        'image',
        () => ImageResolverScope(
          resolver: resolver,
          child: Background.image('fixtures/swatch.png'),
        ),
      ),
    ],
  );
}
