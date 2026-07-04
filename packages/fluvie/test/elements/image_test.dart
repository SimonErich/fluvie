// WI-9 (D5/D6/D17, §15): the Fluvie-owned `Image`. Each factory builds the
// right `MediaSource`; `source` exposes it for the collector; capture paints a
// sync `RawImage` from the resolver; capture without pre-resolution throws a
// typed error naming the source; `shared:` wraps a `SharedElement`; preview
// uses the async fallback; `.animate()` composes.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/frame.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

import '../rendering/fakes/fake_media_resolver.dart';

const _asset = MediaSource.asset('fixtures/swatch.png');

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF2ECC71),
  );
  return recorder.endRecording().toImage(4, 4);
}

FakeMediaResolver _resolverFor(MediaSource source, ui.Image image) => FakeMediaResolver(
  {source: (bytes: Uint8List(0), contentHash: 'x')},
  images: {source: image},
);

void main() {
  group('Image factories build the right MediaSource', () {
    test('network from a String url', () {
      final image = Image.network('https://example.com/p.jpg');
      expect(image.source, MediaSource.network(Uri.parse('https://example.com/p.jpg')));
    });

    test('network from a Uri', () {
      final url = Uri.parse('https://example.com/p.jpg');
      expect(Image.network(url).source, MediaSource.network(url));
    });

    test('asset from a bundle key', () {
      expect(
        Image.asset('fixtures/swatch.png').source,
        const MediaSource.asset('fixtures/swatch.png'),
      );
    });

    test('file from a path', () {
      expect(Image.file('/tmp/a.png').source, const MediaSource.file('/tmp/a.png'));
    });

    test('memory from bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final source = Image.memory(bytes).source;
      expect(source, isA<MemorySource>());
      expect((source as MemorySource).bytes, same(bytes));
    });
  });

  group('capture paint', () {
    testWidgets('paints a sync RawImage with the decoded image and fit', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = _resolverFor(_asset, decoded);
      await resolver.preResolveAll([_asset]);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: Image.asset('fixtures/swatch.png', fit: BoxFit.contain),
          ),
        ),
      );

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(decoded));
      expect(raw.fit, BoxFit.contain);
    });

    testWidgets('capture without pre-resolution throws naming the source', (tester) async {
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: Image.asset('fixtures/swatch.png'),
        ),
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      expect((error as FluvieRenderException).message, contains('fixtures/swatch.png'));
    });
  });

  group('shared: sugar (D6)', () {
    testWidgets('shared: anchor wraps the built child in a SharedElement', (tester) async {
      final anchor = Anchor('logo');
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = _resolverFor(_asset, decoded);
      await resolver.preResolveAll([_asset]);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: Image.asset('fixtures/swatch.png', shared: anchor),
          ),
        ),
      );

      final shared = tester.widget<SharedElement>(find.byType(SharedElement));
      expect(shared.anchor, same(anchor));
    });

    testWidgets('shared: null mounts no SharedElement', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = _resolverFor(_asset, decoded);
      await resolver.preResolveAll([_asset]);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: Image.asset('fixtures/swatch.png'),
          ),
        ),
      );

      expect(find.byType(SharedElement), findsNothing);
    });
  });

  group('frame: wrapping', () {
    testWidgets('wraps the built image in the given Frame', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = _resolverFor(_asset, decoded);
      await resolver.preResolveAll([_asset]);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: Image.asset('fixtures/swatch.png', frame: const Frame.card()),
          ),
        ),
      );

      expect(find.byType(Frame), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Frame), matching: find.byType(flutter.RawImage)),
        findsOneWidget,
      );
    });
  });

  group('preview fallback (no scope)', () {
    testWidgets('preview without a scope uses the async path, no render error', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Image.network('https://example.com/p.jpg'),
        ),
      );
      // Flutter's async Image is mounted (the preview fallback path); the only
      // exception possible is the async network load itself, never a typed
      // FluvieRenderException from a missing pre-resolution.
      expect(find.byType(flutter.Image), findsOneWidget);
      final error = tester.takeException();
      expect(error, isNot(isA<FluvieRenderException>()));
    });
  });

  group('.animate() composes', () {
    testWidgets('kenBurns + slideFade mount a MotionTarget over the Image', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = _resolverFor(_asset, decoded);
      await resolver.preResolveAll([_asset]);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: SizedBox(
            width: 120,
            height: 120,
            child: RenderControllerScope(
              controller: RenderController(),
              child: VideoScope(
                fps: 30,
                duration: const Time.frames(60),
                child: SceneScope(
                  duration: const Time.frames(60),
                  child: Image.asset('fixtures/swatch.png').animate([
                    Animation.kenBurns(zoom: 1.2),
                    Animation.slideFade(),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MotionTarget), findsOneWidget);
      expect(
        find.descendant(of: find.byType(MotionTarget), matching: find.byType(Image)),
        findsOneWidget,
      );
    });
  });
}
