import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show BundleMedia;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/session_media_store.dart';

import 'audio_preview_controller_test.dart' show FakeOutput;
import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

const _picture = MediaStoreEntry(
  id: 'still',
  name: 'still.png',
  kind: MediaStoreKind.image,
  source: {'kind': 'bundle', 'value': 'media/still.png'},
);

EditorCanvas _canvas(WidgetTester tester) => tester.widget<EditorCanvas>(find.byType(EditorCanvas));

ProviderContainer _scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(EditorCanvas)));

Future<void> _pump(WidgetTester tester) async {
  useDesktopSurface(tester);
  final media = SessionMediaStore(materialize: memorySessionMaterializer);
  addTearDown(() {
    media.clear();
    BundleMedia.current = null;
  });
  await media.register(
    'still.png',
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    ),
  );
  await tester.pumpWidget(
    OiApp(
      theme: OiThemeData.dark(),
      home: EditorScreen(
        title: 'placement.fluvie',
        document: EditorDocument.fromJson({
          'fluvieSpec': 1,
          'fps': 30,
          'size': const {'width': 320, 'height': 180},
          'lanes': const [
            {'id': 'picture', 'kind': 'video'},
            {'id': 'locked', 'kind': 'video', 'locked': true},
            {'id': 'sound', 'kind': 'audio'},
          ],
          'scenes': const [
            {'duration': '150f', 'layout': 'canvas'},
            {'duration': '120f', 'layout': 'canvas'},
          ],
          'editor': {
            'deck': const {'mode': 'video'},
            'media': [_picture.toJson()],
          },
        }),
        onClose: () {},
        sessionMedia: media,
        audioPreviewPlatform: FakeOutput(),
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  await tester.pump();
}

Map<String, Object?> _inserted(WidgetTester tester) =>
    (_canvas(tester).document.sceneJson(1)['children']! as List<Object?>).single!
        as Map<String, Object?>;

void main() {
  testWidgets('source monitor places a still at the program clock, selects it, and undoes', (
    tester,
  ) async {
    await _pump(tester);
    final before = _canvas(tester).document.documentDigest;
    _scope(tester).read(activeTimelineLaneProvider.notifier).select('picture');
    _canvas(tester).transport!.seek(180);
    await tester.pump();
    tester.widget<MediaBinPanel>(find.byType(MediaBinPanel)).onPlace!(
      (entry: _picture, start: 0, end: 0),
    );
    await tester.pump();
    final inserted = _inserted(tester);
    expect(inserted['type'], 'Image');
    expect(inserted['source'], _picture.source);
    expect(inserted['lane'], 'picture');
    expect(inserted['show'], {'from': '30f', 'to': '120f'});
    expect(inserted.containsKey('trim'), isFalse);
    expect(_scope(tester).read(selectionProvider), {inserted['id']});
    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pump();
    await tester.pump();
    expect(_canvas(tester).document.documentDigest, before);
    expect(_scope(tester).read(selectionProvider), isEmpty);
    await tester.tap(find.bySemanticsLabel('Redo'));
    await tester.pump();
    expect(_inserted(tester), inserted);
    expect(_scope(tester).read(selectionProvider), {inserted['id']});
    expect(tester.takeException(), isNull);
  });

  testWidgets('a still dropped near the end keeps one visible frame in the target scene', (
    tester,
  ) async {
    await _pump(tester);
    tester.widget<VideoModePanel>(find.byType(VideoModePanel)).onSourceDropped!(
      (entry: _picture, start: 0, end: 0),
      'lane:picture',
      269,
    );
    await tester.pump();
    expect(_inserted(tester)['show'], {'from': '119f', 'to': '120f'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked source destination rejects video before any decode or document edit', (
    tester,
  ) async {
    await _pump(tester);
    final before = _canvas(tester).document.documentDigest;
    _scope(tester).read(activeTimelineLaneProvider.notifier).select('locked');
    const video = MediaStoreEntry(
      id: 'video',
      name: 'video.mp4',
      kind: MediaStoreKind.video,
      source: {'kind': 'file', 'value': '/not-decoded.mp4'},
      fps: 24,
      duration: '8s',
    );
    tester.widget<MediaBinPanel>(find.byType(MediaBinPanel)).onPlace!(
      (entry: video, start: 24, end: 96),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unlock the selected lane before placing media.'), findsOneWidget);
    expect(_canvas(tester).document.documentDigest, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio on a video destination explains the compatible lane without editing', (
    tester,
  ) async {
    await _pump(tester);
    final before = _canvas(tester).document.documentDigest;
    const audio = MediaStoreEntry(
      id: 'audio',
      name: 'audio.wav',
      kind: MediaStoreKind.audio,
      source: {'kind': 'file', 'value': '/not-decoded.wav'},
      fps: 1000,
    );
    tester.widget<VideoModePanel>(find.byType(VideoModePanel)).onSourceDropped!(
      (entry: audio, start: 1000, end: 2000),
      'lane:picture',
      30,
    );
    await tester.pumpAndSettle();
    expect(find.text('Select an audio lane for this source.'), findsOneWidget);
    expect(_canvas(tester).document.documentDigest, before);
    expect(tester.takeException(), isNull);
  });
}
