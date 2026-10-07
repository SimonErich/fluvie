import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show MediaSource;
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:slides/editor/timeline_filmstrips.dart';

final class _Resolver implements MediaResolver {
  _Resolver(this.image);
  final ui.Image image;
  final requested = <int>[];
  bool fail = false;
  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async {
    if (fail) throw StateError('Source temporarily unavailable');
  }

  @override
  Future<ClipMetadata> probeClip(MediaSource source) async => clipMetadataFor(source);
  @override
  ClipMetadata clipMetadataFor(MediaSource source) =>
      (fps: 24, frameCount: 240, width: 160, height: 90, hasAudio: false);
  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> frames) async =>
      requested.addAll(frames);
  @override
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame) => image;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EditorDocument _document({int clips = 1}) => EditorDocument.fromJson({
  'fluvieSpec': 1,
  'fps': 24,
  'scenes': [
    {
      'duration': '10s',
      'children': [
        for (var i = 0; i < clips; i++)
          {
            'id': 'clip-$i',
            'type': 'Clip',
            'source': {'kind': 'file', 'value': '/clip.mp4'},
            'show': {'from': '24f', 'to': '72f'},
            'trim': {'from': '48f', 'to': '96f'},
            'speed': -1,
          },
      ],
    },
  ],
});

void main() {
  testWidgets('visible reversed clip samples exact trim endpoints and retires images', (
    tester,
  ) async {
    final picture = ui.PictureRecorder();
    ui.Canvas(picture).drawColor(const ui.Color(0xff123456), ui.BlendMode.src);
    final drawing = picture.endRecording();
    final image = await drawing.toImage(2, 2);
    drawing.dispose();
    addTearDown(image.dispose);
    final resolver = _Resolver(image);
    final loader = TimelineFilmstrips(resolver: resolver);
    addTearDown(loader.dispose);
    final document = _document();
    loader.request(document, 24, 72);
    await tester.pump();
    expect(resolver.requested, [95, 86, 76, 67, 57, 48]);
    final first = loader.thumbnails.values.single.first;
    loader.request(document, 100, 140);
    await tester.pump();
    expect(loader.thumbnails, isEmpty);
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(first.image.debugDisposed, isTrue);
    expect(image.debugDisposed, isFalse, reason: 'The injected resolver owns its source raster');
  });

  testWidgets('dense timelines stay within 32 images and failed requests can retry', (
    tester,
  ) async {
    final picture = ui.PictureRecorder();
    ui.Canvas(picture).drawColor(const ui.Color(0xff123456), ui.BlendMode.src);
    final drawing = picture.endRecording();
    final image = await drawing.toImage(2, 2);
    drawing.dispose();
    addTearDown(image.dispose);
    final resolver = _Resolver(image)..fail = true;
    final loader = TimelineFilmstrips(resolver: resolver);
    addTearDown(loader.dispose);
    loader.request(_document(clips: 20), 0, 100);
    await tester.pump();
    expect(loader.error, contains('Source temporarily unavailable'));
    resolver.fail = false;
    loader.retry();
    await tester.pump();
    expect(loader.error, isNull);
    expect(loader.thumbnails.values.expand((frames) => frames), hasLength(32));
    expect(resolver.requested, hasLength(32));
  });
}
