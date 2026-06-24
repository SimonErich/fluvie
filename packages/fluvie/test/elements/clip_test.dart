// WI-13 (D7/D17, §15): the Clip embedded-video element. Each factory builds the
// right MediaSource; trim/audio/fit/shared are carried; source exposes the key
// for the collector; capture without pre-resolution throws a typed error;
// shared: wraps a SharedElement; capture paints the resampled source frame.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

import '../rendering/fakes/fake_media_resolver.dart';

const _asset = MediaSource.asset('fixtures/clip_1s.mp4');

Future<ui.Image> _frameImage(int tag) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = ui.Color(0xFF000000 | tag),
  );
  return recorder.endRecording().toImage(4, 4);
}

Future<FakeMediaResolver> _clipResolver(Map<int, ui.Image> frames) async {
  final resolver = FakeMediaResolver(
    const {},
    metadata: {_asset: (fps: 30, frameCount: 30, width: 4, height: 4, hasAudio: false)},
    clipFrames: {_asset: frames},
  );
  await resolver.preResolveClip(_asset, frames.keys);
  return resolver;
}

Widget _harness({required Widget clip, required MediaResolver resolver, int frame = 0}) {
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
            child: SceneScope(duration: const Time.frames(30), child: clip),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('factories build the right MediaSource', () {
    test('asset from a bundle key', () {
      expect(Clip.asset('fixtures/clip_1s.mp4').source, _asset);
    });

    test('network from a Uri', () {
      final url = Uri.parse('https://example.com/b-roll.mp4');
      expect(Clip.network(url).source, MediaSource.network(url));
    });

    test('mediaSource mirrors source for the collector', () {
      final clip = Clip.asset('fixtures/clip_1s.mp4');
      expect(clip.mediaSource, clip.source);
    });
  });

  group('carries its parameters', () {
    test('trim/audio/fit/shared are held verbatim', () {
      final anchor = Anchor('clip');
      final trim = const Time.seconds(0.3).to(const Time.seconds(0.7));
      final clip = Clip.asset(
        'fixtures/clip_1s.mp4',
        trim: trim,
        audio: const ClipAudio.muted(),
        fit: BoxFit.cover,
        shared: anchor,
      );
      expect(clip.trim, trim);
      expect(clip.audio, const ClipAudio.muted());
      expect(clip.fit, BoxFit.cover);
      expect(clip.shared, same(anchor));
    });

    test('audio defaults to included', () {
      expect(Clip.asset('fixtures/clip_1s.mp4').audio, const ClipAudio.included());
    });
  });

  group('capture paint', () {
    testWidgets('paints the resampled source frame as a sync RawImage', (tester) async {
      final f0 = await _frameImage(0x00FF00);
      addTearDown(f0.dispose);
      final resolver = await _clipResolver({0: f0});

      await tester.pumpWidget(
        _harness(
          clip: Clip.asset('fixtures/clip_1s.mp4', fit: BoxFit.cover),
          resolver: resolver,
        ),
      );

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(f0));
      expect(raw.fit, BoxFit.cover);
    });

    testWidgets('a later composition frame reads a later source frame', (tester) async {
      final f0 = await _frameImage(0x00FF00);
      final f10 = await _frameImage(0x0000FF);
      addTearDown(f0.dispose);
      addTearDown(f10.dispose);
      final resolver = await _clipResolver({0: f0, 10: f10});

      await tester.pumpWidget(
        _harness(clip: Clip.asset('fixtures/clip_1s.mp4'), resolver: resolver, frame: 10),
      );

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(f10));
    });

    testWidgets('capture without pre-resolution throws naming the source', (tester) async {
      await tester.pumpWidget(
        SizedBox(
          width: 80,
          height: 80,
          child: FrameProvider(
            frame: 0,
            child: VideoScope(
              fps: 30,
              duration: const Time.frames(30),
              child: RenderModeContext(
                mode: RenderMode.capture,
                child: SceneScope(
                  duration: const Time.frames(30),
                  child: Clip.asset('fixtures/clip_1s.mp4'),
                ),
              ),
            ),
          ),
        ),
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      expect((error as FluvieRenderException).message, contains('fixtures/clip_1s.mp4'));
    });
  });

  group('shared: sugar (D6)', () {
    testWidgets('shared: anchor wraps the built child in a SharedElement', (tester) async {
      final anchor = Anchor('clip');
      final f0 = await _frameImage(0x00FF00);
      addTearDown(f0.dispose);
      final resolver = await _clipResolver({0: f0});

      await tester.pumpWidget(
        _harness(
          clip: Clip.asset('fixtures/clip_1s.mp4', shared: anchor),
          resolver: resolver,
        ),
      );

      expect(tester.widget<SharedElement>(find.byType(SharedElement)).anchor, same(anchor));
    });

    testWidgets('shared: null mounts no SharedElement', (tester) async {
      final f0 = await _frameImage(0x00FF00);
      addTearDown(f0.dispose);
      final resolver = await _clipResolver({0: f0});

      await tester.pumpWidget(
        _harness(clip: Clip.asset('fixtures/clip_1s.mp4'), resolver: resolver),
      );

      expect(find.byType(SharedElement), findsNothing);
    });
  });
}
