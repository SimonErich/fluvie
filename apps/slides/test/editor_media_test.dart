import 'dart:io';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show BundleMedia;
import 'package:fluvie_editor/fluvie_editor.dart'
    show
        EditorCanvas,
        EditorDocument,
        EditorDocumentMedia,
        EditorInspector,
        EditorTip,
        EditorToolbar,
        LayersPanel,
        MediaImporter,
        MediaPick,
        SlideStrip,
        ThemePanel;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiFileDropTarget, OiIconButton, OiThemeData;
import 'package:slides/editor/dropped_media_web.dart' as web_media;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/file_media_importer.dart';
import 'package:slides/editor/renamable_title.dart';
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/loader/fluvie_file_saver.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-photo',
          'type': 'Image',
          'source': {'kind': 'file', 'value': '/media/photo.png'},
          'transform': {'x': 0.3, 'y': 0.4, 'w': 0.3, 'h': 0.3},
        },
      ],
    },
  ],
};

final class _NeverSaver implements FluvieFileSaver {
  @override
  String? get targetPath => null;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async => null;

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async => null;

  @override
  Future<String?> saveCopyBytes({required String suggestedName, required List<int> bytes}) async =>
      null;

  @override
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  }) async => null;
}

final class _NeverImporter implements MediaImporter {
  @override
  Future<MediaPick?> pickMedia() async => null;
}

/// An importer standing in for a successful file pick.
final class _PickImporter implements MediaImporter {
  _PickImporter(this.pick);

  final MediaPick pick;

  @override
  Future<MediaPick?> pickMedia() async => pick;
}

/// An importer standing in for a web pick that overruns the session budget.
final class _RefusingImporter implements MediaImporter {
  @override
  Future<MediaPick?> pickMedia() async =>
      throw const SessionMediaBudgetError(attemptedBytes: 9, heldBytes: 1, budgetBytes: 4);
}

Future<DocumentHistoryProbe> _pump(
  WidgetTester tester, {
  Map<String, Object?>? deck,
  MediaImporter? importer,
}) async {
  useDesktopSurface(tester);
  final probe = DocumentHistoryProbe();
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(deck ?? _deck()),
        title: 'mine.fluvie',
        onClose: () {},
        saver: _NeverSaver(),
        importer: importer ?? _NeverImporter(),
        autosave: MemoryAutosaveStore(),
        key: probe.key,
      ),
    ),
  );
  await tester.pump();
  return probe;
}

/// Reaches the mounted screen's document through the widget tree.
final class DocumentHistoryProbe {
  final GlobalKey key = GlobalKey();

  EditorDocument documentOf(WidgetTester tester) {
    // The screen's history is private; read the canvas's document instead.
    return tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
  }
}

void main() {
  group('mediaPickFor', () {
    test('a platform path becomes a file source', () async {
      final pick = await mediaPickFor(name: 'clip.mp4', path: '/abs/clip.mp4');
      expect(pick!.source, {'kind': 'file', 'value': '/abs/clip.mp4'});
      expect(pick.isVideo, isTrue);
    });

    test('a browser object URL is never serialized as a file path', () async {
      final pick = await mediaPickFor(
        name: 'photo.png',
        path: 'blob:https://editor.fluvie.dev/1234',
        bytes: [1, 2, 3],
      );
      expect(pick!.source['value'], isNot('blob:https://editor.fluvie.dev/1234'));
      expect(pick.source['kind'], 'file'); // VM test materializes bytes to a temp file.
      File(pick.source['value']! as String).deleteSync();
    });

    test('bytes are materialized to a real temp file on desktop', () async {
      final pick = await mediaPickFor(name: 'photo.png', bytes: [1, 2, 3]);
      expect(pick!.isVideo, isFalse);
      expect(pick.source['kind'], 'file');
      final file = File(pick.source['value']! as String);
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), [1, 2, 3]);
      file.deleteSync();
    });

    test('non-media names and empty payloads are refused', () async {
      expect(await mediaPickFor(name: 'notes.txt', path: '/x/notes.txt'), isNull);
      expect(await mediaPickFor(name: 'photo.png'), isNull);
      expect(await mediaPickFor(name: 'photo.png', bytes: const []), isNull);
    });

    test('extensions classify image against video against audio', () {
      expect(isVideoName('a.MOV'), isTrue);
      expect(isVideoName('a.webp'), isFalse);
      expect(isMediaName('a.jpeg'), isTrue);
      expect(isMediaName('a.txt'), isFalse);
      expect(isAudioName('bed.MP3'), isTrue);
      expect(isAudioName('a.mp4'), isFalse);
      expect(isMediaName('bed.flac'), isTrue);
    });

    test('a pick carries the import metadata the media store records', () async {
      final pick = await mediaPickFor(name: 'clip.mp4', path: '/abs/clip.mp4', bytes: [1, 2]);
      expect(pick!.name, 'clip.mp4');
      expect(pick.sizeBytes, 2);
      expect(pick.isAudio, isFalse);

      final audio = await mediaPickFor(name: 'bed.mp3', path: '/abs/bed.mp3');
      expect(audio!.isAudio, isTrue);
      expect(audio.isVideo, isFalse);
      expect(audio.source, {'kind': 'file', 'value': '/abs/bed.mp3'});
    });
  });

  group('the web materializer registers session bytes', () {
    tearDown(() {
      sessionMediaStore.clear();
      BundleMedia.current = null;
    });

    test('dropped bytes become a bundle source backed by the session store', () async {
      final source = await web_media.materializeDroppedMedia('photo.png', [1, 2, 3]);
      expect(source, {'kind': 'bundle', 'value': 'media/photo.png'});
      expect(sessionMediaStore.bytesFor('media/photo.png'), [1, 2, 3]);
      expect(BundleMedia.current!.media['media/photo.png'], isNotNull);
    });
  });

  testWidgets('the editor shows the toolbar and a media drop target', (tester) async {
    await _pump(tester);
    expect(find.byType(EditorToolbar), findsOneWidget);
    expect(find.bySemanticsLabel('Select tool (V)'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(EditorScreen), matching: find.byType(OiFileDropTarget)),
      findsOneWidget,
    );
  });

  testWidgets('an import past the session budget shows a visible refusal', (tester) async {
    final probe = await _pump(tester, importer: _RefusingImporter());
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();
    expect(find.textContaining('media budget'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(probe.documentOf(tester).elementIdsInScene(0), hasLength(1));
  });

  testWidgets('the deck assets dialog lists store entries and removes them', (tester) async {
    final deck = _deck();
    deck['editor'] = {
      'media': [
        {
          'id': 'media-1',
          'name': 'bed.mp3',
          'kind': 'audio',
          'source': {'kind': 'file', 'value': '/media/bed.mp3'},
        },
      ],
    };
    final probe = await _pump(tester, deck: deck);
    await tester.tap(find.bySemanticsLabel('Deck assets'));
    await tester.pumpAndSettle();
    expect(find.text('bed.mp3'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Remove bed.mp3').first);
    await tester.pumpAndSettle();
    expect(probe.documentOf(tester).mediaEntries, isEmpty);
  });

  testWidgets('the asset panel inserts a reused source on the current slide', (tester) async {
    final probe = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Deck assets'));
    await tester.pumpAndSettle();
    expect(find.text('photo.png'), findsOneWidget);

    await tester.tap(find.text('photo.png'));
    await tester.pumpAndSettle();
    final document = probe.documentOf(tester);
    final ids = document.elementIdsInScene(0);
    expect(ids, hasLength(2));
    final inserted = document.elementJson(ids.last)!;
    expect(inserted['type'], 'Image');
    expect(inserted['source'], {'kind': 'file', 'value': '/media/photo.png'});
  });

  testWidgets('the assets dialog import control picks and inserts a file', (tester) async {
    const pick = MediaPick(
      source: {'kind': 'file', 'value': '/media/added.png'},
      isVideo: false,
      name: 'added.png',
      sizeBytes: 3,
    );
    final probe = await _pump(tester, importer: _PickImporter(pick));
    await tester.tap(find.bySemanticsLabel('Deck assets'));
    await tester.pumpAndSettle();
    expect(find.text('Import media'), findsOneWidget);

    await tester.tap(find.text('Import media'));
    await tester.pumpAndSettle();
    final document = probe.documentOf(tester);
    final ids = document.elementIdsInScene(0);
    expect(ids, hasLength(2));
    expect(document.elementJson(ids.last)!['source'], {
      'kind': 'file',
      'value': '/media/added.png',
    });
  });

  testWidgets('a cancelled assets import leaves the slide untouched', (tester) async {
    final probe = await _pump(tester, importer: _NeverImporter());
    await tester.tap(find.bySemanticsLabel('Deck assets'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import media'));
    await tester.pumpAndSettle();
    expect(probe.documentOf(tester).elementIdsInScene(0), hasLength(1));
  });

  testWidgets('video mode imports into the bin before source placement', (tester) async {
    final deck = _deck();
    deck['editor'] = {
      'deck': {'mode': 'video'},
    };
    const pick = MediaPick(
      source: {'kind': 'file', 'value': '/media/added.png'},
      isVideo: false,
      name: 'added.png',
      sizeBytes: 3,
    );
    final probe = await _pump(tester, deck: deck, importer: _PickImporter(pick));
    // The video-mode assets surface is a fixture, not a dialog.
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Import media'), findsOneWidget);

    await tester.tap(find.text('Import media'));
    await tester.pumpAndSettle();
    expect(probe.documentOf(tester).elementIdsInScene(0), hasLength(1));
    expect(probe.documentOf(tester).mediaEntries.single.name, 'added.png');
  });
  inspectorShellSuite();
}

// The inspector rides the editor shell.
void inspectorShellSuite() {
  testWidgets('the editor mounts the inspector panel', (tester) async {
    await _pump(tester);
    expect(find.byType(EditorInspector), findsOneWidget);
    expect(find.text('Slide'), findsOneWidget);
  });
  panelsShellSuite();
}

// The panels ride the editor shell.
void panelsShellSuite() {
  testWidgets('the editor mounts the slide strip and layers tab', (tester) async {
    await _pump(tester);
    expect(find.byType(SlideStrip), findsOneWidget);
    await tester.tap(find.text('Layers'));
    await tester.pump();
    expect(find.byType(LayersPanel), findsOneWidget);
    await tester.tap(find.text('Slides'));
    await tester.pump();
    expect(find.byType(SlideStrip), findsOneWidget);
  });

  testWidgets('the theme tab mounts the theme panel and its edits land', (tester) async {
    final probe = await _pump(tester);
    await tester.tap(find.text('Theme'));
    await tester.pump();
    expect(find.byType(ThemePanel), findsOneWidget);
    await tester.tap(find.text('midnight'));
    await tester.pump();
    expect(
      (probe.documentOf(tester).toJson()['theme']! as Map).containsKey('palette'),
      isTrue,
      reason: 'the start-from chip applied a builtin theme to the deck',
    );
  });
  polishShellSuite();
}

// The 3.5 polish: inline deck rename and the tooltip sweep.
void polishShellSuite() {
  testWidgets('double-clicking the deck name renames it inline', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('mine.fluvie'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('mine.fluvie'));
    await tester.pump();
    final field = find.descendant(
      of: find.byType(RenamableTitle),
      matching: find.byType(EditableText),
    );
    expect(field, findsOneWidget);
    await tester.enterText(field, 'deck.fluvie');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('deck.fluvie'), findsOneWidget);
    expect(find.text('mine.fluvie'), findsNothing);
  });

  testWidgets('every icon-only control carries a tooltip', (tester) async {
    await _pump(tester);
    final buttons = find.byWidgetPredicate((widget) => widget is OiIconButton);
    expect(buttons, findsWidgets);
    for (final element in buttons.evaluate()) {
      final wrapped = element.findAncestorWidgetOfExactType<EditorTip>();
      expect(
        wrapped,
        isNotNull,
        reason:
            'icon-only control without a tooltip: '
            '${(element.widget as OiIconButton).semanticLabel}',
      );
    }
  });
}
