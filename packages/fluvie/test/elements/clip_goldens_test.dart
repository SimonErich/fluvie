// WI-16 (D7/D9/D18): the Clip goldens. Canned RawFrame images are decoded in
// `main`, pre-resolved through a FakeMediaResolver (no real ffmpeg), and carried
// down by an ImageResolverScope, so each golden is font-free and byte-stable.
// clip_frame_at_0 reads source frame 0; clip_frame_at_mid reads a later source
// frame at a later composition frame (proving the D9 mapping); clip_trimmed
// proves trim: 0.3s..0.7s starts at the trimmed source frame 9.
@Tags(['golden'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Clip, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';

import '../animation/helpers/golden_frame.dart';
import '../rendering/fakes/fake_media_resolver.dart';

const _clip = MediaSource.asset('fixtures/clip_1s.mp4');

/// A solid 16x16 swatch tagged by [color], standing in for one source frame.
Future<ui.Image> _swatch(int color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 16, 16),
    ui.Paint()..color = ui.Color(0xFF000000 | color),
  );
  return recorder.endRecording().toImage(16, 16);
}

Future<void> main() async {
  final frame0 = await _swatch(0x2980B9); // blue: source frame 0
  final frame15 = await _swatch(0x27AE60); // green: source frame 15
  final frame9 = await _swatch(0xC0392B); // red: trimmed source frame 9

  final resolver = FakeMediaResolver(
    {_clip: (bytes: Uint8List(0), contentHash: 'x')},
    metadata: {_clip: const (fps: 30, frameCount: 30, width: 16, height: 16, hasAudio: false)},
    clipFrames: {
      _clip: {0: frame0, 15: frame15, 9: frame9},
    },
  );
  await resolver.preResolveClip(_clip, const [0, 15, 9]);

  Widget scoped(Widget child) => _ScopedResolver(resolver: resolver, child: child);

  await goldenMotionFrames(
    description: 'Clip: composition frame 0 reads source frame 0',
    fileName: 'clip_frame_at_0',
    frames: const [0],
    subject: () => scoped(Clip.asset('fixtures/clip_1s.mp4', fit: BoxFit.cover)),
  );

  await goldenMotionFrames(
    description: 'Clip: composition frame 15 reads source frame 15 (D9 identity mapping)',
    fileName: 'clip_frame_at_mid',
    frames: const [15],
    subject: () => scoped(Clip.asset('fixtures/clip_1s.mp4', fit: BoxFit.cover)),
  );

  await goldenMotionFrames(
    description: 'Clip: trim 0.3s..0.7s starts at source frame 9 at composition frame 0',
    fileName: 'clip_trimmed',
    frames: const [0],
    subject: () => scoped(
      Clip.asset(
        'fixtures/clip_1s.mp4',
        fit: BoxFit.cover,
        trim: const Time.seconds(0.3).to(const Time.seconds(0.7)),
      ),
    ),
  );
}

/// Wraps [child] in an [ImageResolverScope] so the clip paints synchronously
/// from the canned [resolver].
final class _ScopedResolver extends StatelessWidget {
  const _ScopedResolver({required this.resolver, required this.child});

  final MediaResolver resolver;
  final Widget child;

  @override
  Widget build(BuildContext context) => ImageResolverScope(resolver: resolver, child: child);
}
