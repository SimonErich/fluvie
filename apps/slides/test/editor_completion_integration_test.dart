import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/editor_screen.dart';

import 'audio_preview_controller_test.dart' show FakeOutput;
import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

EditorDocument _document({bool video = true}) => EditorDocument.fromJson({
  'fluvieSpec': 1,
  'fps': 30,
  'size': const {'width': 320, 'height': 180},
  'lanes': const [
    {'id': 'picture', 'kind': 'video', 'name': 'Picture'},
    {'id': 'sound', 'kind': 'audio', 'name': 'Sound'},
  ],
  'scenes': const [
    {'duration': '5s', 'layout': 'canvas', 'children': <Object?>[]},
  ],
  'editor': {
    'deck': {'mode': video ? 'video' : 'slides'},
  },
});

Future<void> _pump(WidgetTester tester, {bool video = true}) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    OiApp(
      home: EditorScreen(
        document: _document(video: video),
        title: 'acceptance.fluvie',
        onClose: () {},
        autosave: MemoryAutosaveStore(),
        audioPreviewPlatform: FakeOutput(),
      ),
    ),
  );
  await tester.pump();
}

EditorCanvas _canvas(WidgetTester tester) => tester.widget<EditorCanvas>(find.byType(EditorCanvas));

void main() {
  testWidgets('preview quality and draft bypass never change the authored document', (
    tester,
  ) async {
    await _pump(tester);
    final digest = _canvas(tester).document.documentDigest;
    await tester.tap(find.text('Quarter'));
    await tester.pump();
    expect(_canvas(tester).previewMaxEdge, 80);
    await tester.tap(find.text('Effects on'));
    await tester.pump();
    expect(_canvas(tester).bypassEffects, isTrue);
    expect(_canvas(tester).document.documentDigest, digest);
    expect(find.text('Saved'), findsOneWidget);
  });

  for (final video in [false, true]) {
    testWidgets('changing fps rebuilds the ${video ? "video" : "slide"} clock at the same time', (
      tester,
    ) async {
      await _pump(tester, video: video);
      _canvas(tester).transport!.seek(30);
      _canvas(tester).onCommand!(const UpdateVideoCommand(patch: {'fps': 60}));
      await tester.pump();
      await tester.pump();
      expect(_canvas(tester).transport!.fps, 60);
      expect(_canvas(tester).transport!.frame, 60);
      expect(_canvas(tester).document.spec.fps, 60);
    });
  }

  testWidgets('a marked audio source lands on the dropped lane at the requested time', (
    tester,
  ) async {
    await _pump(tester);
    final panel = tester.widget<VideoModePanel>(find.byType(VideoModePanel));
    const entry = MediaStoreEntry(
      id: 'music',
      name: 'bed.wav',
      kind: MediaStoreKind.audio,
      source: {'kind': 'file', 'value': '/media/bed.wav'},
      duration: '10s',
      fps: 1000,
    );
    panel.onSourceDropped!((entry: entry, start: 2000, end: 3500), 'lane:sound', 30);
    await tester.pump();
    final document = _canvas(tester).document;
    final audio = (document.sceneJson(0)['audio']! as List).single as Map;
    expect(audio['lane'], 'sound');
    expect(audio['at'], {'kind': 'at', 'time': '30f'});
    expect(audio['trim'], {'from': '2.0s', 'to': '3.5s'});
    expect(audio['loop'], isFalse);
  });

  testWidgets('an incompatible source drop explains why the document was not changed', (
    tester,
  ) async {
    await _pump(tester);
    final digest = _canvas(tester).document.documentDigest;
    const entry = MediaStoreEntry(
      id: 'still',
      name: 'still.png',
      kind: MediaStoreKind.image,
      source: {'kind': 'file', 'value': '/media/still.png'},
    );
    tester.widget<VideoModePanel>(find.byType(VideoModePanel)).onSourceDropped!(
      (entry: entry, start: 0, end: 0),
      'lane:sound',
      0,
    );
    await tester.pumpAndSettle();
    expect(find.text('Select a video lane for this source.'), findsOneWidget);
    expect(_canvas(tester).document.documentDigest, digest);
  });
}
