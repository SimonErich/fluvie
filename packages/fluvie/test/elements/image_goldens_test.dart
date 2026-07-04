// WI-12 (D5/D18): the Image goldens. A tiny solid swatch is decoded in `main`,
// pre-resolved through a FakeMediaResolver, and carried down by an
// ImageResolverScope, so each golden is font-free (Ahem for the caption) and
// byte-stable: image_static_cover (fit: cover), image_framed_polaroid (a
// captioned polaroid), and image_kenburns_mid (mid-kenBurns zoom).
@Tags(['golden'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/photo_frame.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';

import '../animation/helpers/golden_frame.dart';
import '../rendering/fakes/fake_media_resolver.dart';

const _swatch = MediaSource.asset('fixtures/swatch.png');
const _canvas = Size(160, 160);

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 16, 16),
    ui.Paint()..color = const ui.Color(0xFF2980B9),
  );
  return recorder.endRecording().toImage(16, 16);
}

Future<void> main() async {
  final image = await _solidImage();
  final resolver = FakeMediaResolver(
    {_swatch: (bytes: Uint8List(0), contentHash: 'x')},
    images: {_swatch: image},
  );
  await resolver.preResolveAll([_swatch]);

  Widget scoped(Widget child) => ImageResolverScope(resolver: resolver, child: child);

  await goldenMotionVariants(
    description: 'Image: a pre-resolved swatch scaled cover',
    fileName: 'image_static_cover',
    frame: 0,
    size: _canvas,
    variants: [
      ('cover', () => scoped(Image.asset('fixtures/swatch.png', fit: BoxFit.cover))),
    ],
  );

  await goldenMotionVariants(
    description: 'Image: a captioned polaroid frame around the swatch',
    fileName: 'image_framed_polaroid',
    frame: 0,
    size: _canvas,
    variants: [
      (
        'polaroid',
        () => scoped(
          Center(
            child: Image.asset(
              'fixtures/swatch.png',
              fit: BoxFit.cover,
              frame: const PhotoFrame.polaroid(caption: 'Summer'),
            ),
          ),
        ),
      ),
    ],
  );

  await goldenMotionFrames(
    description: 'Image: kenBurns zoom probed mid-span',
    fileName: 'image_kenburns_mid',
    frames: const [30],
    subject: () => scoped(
      Image.asset('fixtures/swatch.png', fit: BoxFit.cover).animate([
        Animation.kenBurns(zoom: 1.4),
      ]),
    ),
  );
}
