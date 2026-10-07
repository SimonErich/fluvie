import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show MediaSource;
import 'package:fluvie/rendering.dart' show ClipMetadata, MediaResolver;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

final class _Resolver implements MediaResolver {
  _Resolver(this.image, this.fps, this.frameCount);
  final ui.Image image;
  double fps;
  int frameCount;
  int preparations = 0;
  final decoded = <int>{};
  final painted = <int>[];
  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async {
    preparations++;
  }

  @override
  Future<ClipMetadata> probeClip(MediaSource source) async => clipMetadataFor(source);
  @override
  ClipMetadata clipMetadataFor(MediaSource source) =>
      (fps: fps, frameCount: frameCount, width: 32, height: 18, hasAudio: false);
  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    decoded.addAll(sourceFrames);
  }

  @override
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame) {
    if (!decoded.contains(sourceFrame)) {
      throw StateError('Source frame $sourceFrame is not decoded');
    }
    painted.add(sourceFrame);
    return image;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(const ui.Rect.fromLTWH(0, 0, 32, 18), ui.Paint()..color = const ui.Color(0xff009933));
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(32, 18);
  } finally {
    picture.dispose();
  }
}

MediaStoreEntry _entry(double fps, int count) => MediaStoreEntry(
  id: 'source',
  name: 'Fractional rate.mp4',
  kind: MediaStoreKind.video,
  source: const {'kind': 'file', 'value': '/source.mp4'},
  duration: '${count / fps}s',
  fps: fps,
  width: 32,
  height: 18,
);

Future<void> _show(
  WidgetTester tester,
  MediaStoreEntry entry,
  int frame,
  MediaResolver resolver,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: OiApp(
        home: SourceMediaPreview(
          entry: entry,
          frame: frame,
          mediaResolver: resolver,
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

void main() {
  for (final rate in [29.97, 23.976, 59.94]) {
    testWidgets('$rate fps source scrub paints exact beginning, middle and final source frame', (
      tester,
    ) async {
      final image = await _image();
      addTearDown(image.dispose);
      const count = 301;
      final resolver = _Resolver(image, rate, count);
      final entry = _entry(rate, count);
      for (final frame in [0, 1, 150, count - 1]) {
        resolver.painted.clear();
        await _show(tester, entry, frame, resolver);
        expect(tester.takeException(), isNull);
        expect(resolver.painted, isNotEmpty);
        expect(resolver.painted.last, frame);
        expect(resolver.decoded, contains(frame));
        final canvas = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
        expect(
          canvas.transport!.frame,
          lessThan(canvas.transport!.length),
          reason: 'The final source frame needs a live composition sample.',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'marks and copied source maps retain decoder and clock; probed metadata refreshes them',
    (tester) async {
      final image = await _image();
      addTearDown(image.dispose);
      final resolver = _Resolver(image, 29.97, 301);
      final entry = _entry(29.97, 301);
      await _show(tester, entry, 30, resolver);
      final first = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
      final preparations = resolver.preparations;
      final marked = MediaStoreEntry.fromJson({...entry.toJson(), 'in': 30, 'out': 200});
      expect(identical(marked.source, entry.source), isFalse);
      await _show(tester, marked, 40, resolver);
      final afterMark = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
      expect(afterMark.document, same(first.document));
      expect(afterMark.transport, same(first.transport));
      expect(resolver.preparations, preparations);
      expect(resolver.painted.last, 40);
      resolver
        ..fps = 59.94
        ..frameCount = 600;
      final probed = MediaStoreEntry.fromJson({
        ...marked.toJson(),
        'width': 64,
        'height': 36,
        'fps': 59.94,
        'duration': '${600 / 59.94}s',
      });
      await _show(tester, probed, 599, resolver);
      final afterProbe = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
      expect(afterProbe.transport, isNot(same(first.transport)));
      expect(afterProbe.document.spec.size.width, 64);
      expect(afterProbe.document.spec.size.height, 36);
      expect(afterProbe.document.spec.fps, 60);
      expect(resolver.painted.last, 599);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
