// WI-16 (D7/D9): the Clip determinism proof. Two pumps of the same clip at the
// same composition frame paint the identical source-frame ui.Image (a content
// hash and frame index that never drift), the byte-equality guarantee the cache
// and goldens rely on.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Clip, Image;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

import '../rendering/fakes/fake_media_resolver.dart';

const _clip = MediaSource.asset('fixtures/clip_1s.mp4');

Future<ui.Image> _swatch() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0xFF8E44AD),
  );
  return recorder.endRecording().toImage(8, 8);
}

Widget _harness(MediaResolver resolver, int frame) => ImageResolverScope(
  resolver: resolver,
  child: SizedBox(
    width: 60,
    height: 60,
    child: FrameProvider(
      frame: frame,
      child: VideoScope(
        fps: 30,
        duration: const Time.frames(30),
        child: RenderModeContext(
          mode: RenderMode.capture,
          child: SceneScope(
            duration: const Time.frames(30),
            child: Clip.asset('fixtures/clip_1s.mp4', fit: BoxFit.cover),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('two pumps at the same frame paint the identical source frame', (tester) async {
    final image = await _swatch();
    addTearDown(image.dispose);
    final resolver = FakeMediaResolver(
      {_clip: (bytes: Uint8List(0), contentHash: 'x')},
      metadata: {_clip: const (fps: 30, frameCount: 30, width: 8, height: 8)},
      clipFrames: {
        _clip: {6: image},
      },
    );
    await resolver.preResolveClip(_clip, const [6]);

    await tester.pumpWidget(_harness(resolver, 6));
    final first = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage)).image;

    await tester.pumpWidget(_harness(resolver, 6));
    final second = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage)).image;

    expect(first, same(second), reason: 'the resampled source frame must be identical');
    expect(identical(first, image), isTrue);
  });
}
