// The preview half of the capture shell: PreviewMediaScope runs the same
// pre-resolve pass a render runs, then mounts the same ImageResolverScope, so a
// Clip paints real frames in a live preview through the capture painter rather
// than a second, divergent decode path. A warm-up that cannot run must degrade
// to the placeholder, never to an exception.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/preview_media_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

import '../fakes/fake_media_resolver.dart';

const _clip = MediaSource.asset('fixtures/clip_1s.mp4');

/// A resolver with everything a warm-up needs: a 4-frame 30fps source matching
/// the 4-frame composition below one-to-one.
FakeMediaResolver _readyResolver(ui.Image image) => FakeMediaResolver(
  {_clip: (bytes: Uint8List(0), contentHash: 'x')},
  metadata: {
    _clip: (fps: 30, frameCount: 4, width: 4, height: 4, hasAudio: false),
  },
  clipFrames: {
    _clip: {0: image, 1: image, 2: image, 3: image},
  },
);

/// Holds the pre-pass open until its gate completes, so a test can tear the tree
/// down while a warm-up is genuinely in flight (a plain fake resolves in
/// microtasks, before an unmount can land).
final class _GatedResolver implements MediaResolver {
  _GatedResolver(this._inner, this._gate);

  final FakeMediaResolver _inner;
  final Future<void> _gate;

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async {
    await _gate;
    await _inner.preResolveAll(sources);
  }

  @override
  Future<ClipMetadata> probeClip(MediaSource source) => _inner.probeClip(source);

  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) =>
      _inner.preResolveClip(source, sourceFrames);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ui.Image> _frameImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  return recorder.endRecording().toImage(4, 4);
}

Video _video() => Video(
  size: VideoSize.square,
  fps: 30,
  scenes: [
    Scene(
      duration: const Time.frames(4),
      children: [Clip.asset('fixtures/clip_1s.mp4')],
    ),
  ],
);

/// Mounts [scope] under the same frame clock a real preview uses, so the clip
/// painter can resample exactly as it does in capture.
Widget _harness(Widget scope, RenderController controller) => Directionality(
  textDirection: TextDirection.ltr,
  child: RenderControllerScope(
    controller: controller,
    child: Center(child: SizedBox(width: 80, height: 80, child: scope)),
  ),
);

void main() {
  late RenderController controller;

  setUp(() => controller = RenderController());
  tearDown(() => controller.dispose());

  testWidgets('mounts an ImageResolverScope once warm-up completes', (tester) async {
    final image = await _frameImage();
    addTearDown(image.dispose);
    final resolver = _readyResolver(image);

    await tester.pumpWidget(
      _harness(PreviewMediaScope(composition: _video(), resolver: resolver), controller),
    );
    // Before the async warm-up settles the tree has no resolver: the placeholder.
    expect(find.byType(flutter.RawImage), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(ImageResolverScope), findsOneWidget);
    expect(
      tester.widget<flutter.RawImage>(find.byType(flutter.RawImage)).image,
      same(image),
      reason: 'preview must paint through the capture painter, not a second decode path',
    );
  });

  testWidgets('a warm-up failure degrades to the placeholder and reports why', (tester) async {
    // A resolver with no canned media for the clip: preResolveAll throws, which
    // is what a missing ffmpeg or an absent WebCodecs decoder looks like.
    final resolver = FakeMediaResolver(const {});

    await tester.pumpWidget(
      _harness(PreviewMediaScope(composition: _video(), resolver: resolver), controller),
    );
    await tester.pumpAndSettle();

    // Reported, not thrown: the tree still builds, but a silent placeholder
    // would leave the author with no way to find out why.
    final reported = tester.takeException();
    expect(reported, isA<FluvieRenderException>());
    expect(find.byType(ImageResolverScope), findsNothing);
    expect(find.byType(flutter.RawImage), findsNothing);
    expect(
      find.byType(_video().runtimeType),
      findsOneWidget,
      reason: 'the composition still shows',
    );
  });

  testWidgets('an injected resolver is left for its owner to dispose', (tester) async {
    final image = await _frameImage();
    addTearDown(image.dispose);
    final resolver = _readyResolver(image);

    await tester.pumpWidget(
      _harness(PreviewMediaScope(composition: _video(), resolver: resolver), controller),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });

  test('a non-positive maxClipEdge is rejected, not silently decoded at 2x2', () {
    expect(
      () => PreviewMediaScope(composition: _video(), maxClipEdge: 0),
      throwsA(isA<AssertionError>()),
      reason: 'null is how you say "no bound"; 0 would collapse every clip',
    );
    expect(
      () => PreviewMediaScope(composition: _video(), maxClipEdge: -5),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('a composition with no Video mounts no scope and reports nothing', (tester) async {
    await tester.pumpWidget(
      _harness(
        PreviewMediaScope(composition: const SizedBox(), resolver: FakeMediaResolver(const {})),
        controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'nothing to resolve is not a failure');
    expect(find.byType(ImageResolverScope), findsNothing);
  });

  testWidgets('a new composition re-runs the warm-up against it', (tester) async {
    final image = await _frameImage();
    addTearDown(image.dispose);

    await tester.pumpWidget(
      _harness(
        PreviewMediaScope(composition: _video(), resolver: _readyResolver(image)),
        controller,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ImageResolverScope), findsOneWidget);

    // A different Video instance: the warm-up is keyed to the composition's
    // media, so it must run again rather than serve the old resolver.
    await tester.pumpWidget(
      _harness(
        PreviewMediaScope(composition: _video(), resolver: _readyResolver(image)),
        controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ImageResolverScope), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a warm-up landing after unmount releases it and never setStates', (tester) async {
    final image = await _frameImage();
    addTearDown(image.dispose);
    final gate = Completer<void>();
    final resolver = _GatedResolver(_readyResolver(image), gate.future);

    await tester.pumpWidget(
      _harness(PreviewMediaScope(composition: _video(), resolver: resolver), controller),
    );
    // Tear the tree down while the warm-up is genuinely blocked, then let it
    // finish: it must drop the resolver it warmed instead of setStating a dead
    // element or leaking the decoded frames.
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ImageResolverScope), findsNothing);
  });
}
