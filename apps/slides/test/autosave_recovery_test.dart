import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show BundleMedia, MemorySource;
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas, EditorDocument;
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';
import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';
import 'start_screen_robot.dart';

/// The tips card never gets in the way of an editor journey.
MemoryStartPrefsStore _prefs() => MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true));

const Map<String, Object?> _fileSpec = {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'type': 'Text',
          'text': 'from the file',
          'style': {'color': '#FFFFFF', 'fontSize': 40},
        },
      ],
    },
  ],
};

final class _FakeSaver implements FluvieFileSaver {
  String? nextName = 'mine.fluvie';

  @override
  String? targetPath;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    if (nextName != null) targetPath = '/decks/$nextName';
    return nextName;
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async =>
      nextName;

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

final class _BrokenStore implements AutosaveStore {
  @override
  Future<AutosaveSnapshot?> read(String key) async => throw StateError('read');

  @override
  Future<void> write(
    String key,
    AutosaveRecord record, {
    Map<String, Uint8List> media = const {},
  }) async => throw StateError('write');

  @override
  Future<void> clear(String key) async => throw StateError('clear');
}

final class _Harness {
  final MemoryAutosaveStore autosave = MemoryAutosaveStore();
  final MemoryRecents recents = MemoryRecents();
  final _FakeSaver saver = _FakeSaver();
  final SessionMediaStore session = SessionMediaStore(materialize: memorySessionMaterializer);
}

Future<void> _pumpApp(WidgetTester tester, _Harness harness, {AutosaveStore? autosave}) async {
  useDesktopSurface(tester);
  addTearDown(harness.session.clear);
  await tester.pumpWidget(
    SlidesApp(
      openFile: () async =>
          parseFluvieJson('file.fluvie', jsonEncode(_fileSpec), path: '/decks/file.fluvie'),
      openPath: (path) async => parseFluvieJson('file.fluvie', jsonEncode(_fileSpec), path: path),
      saver: harness.saver,
      recents: harness.recents,
      autosave: autosave ?? harness.autosave,
      sessionMedia: harness.session,
      startPrefs: _prefs(),
    ),
  );
  await tester.pump();
}

Future<void> _openBlank(WidgetTester tester) async {
  await tester.ensureVisible(find.text('New deck'));
  await tester.tap(find.text('New deck'));
  await tester.pump();
  await tester.pump();
}

Future<void> _openFileForEdit(WidgetTester tester) async {
  await openDeckForEdit(tester);
}

Future<void> _typeHeadline(WidgetTester tester, String text) async {
  final canvas = tester.getRect(find.byType(EditorCanvas));
  const size = Size(1920, 1080);
  const margin = 48.0;
  final scale = math.min(
    (canvas.width - 2 * margin) / size.width,
    (canvas.height - 2 * margin) / size.height,
  );
  final origin = canvas.center - Offset(size.width / 2 * scale, size.height / 2 * scale);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
  await tester.pump();
  await tester.tapAt(origin + const Offset(960, 400) * scale);
  await tester.pump();
  await tester.enterText(find.byType(EditableText).first, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

EditorDocument _document(WidgetTester tester) =>
    tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;

void main() {
  testWidgets('edit, crash, reopen, recover — then save clears the autosave', (tester) async {
    final harness = _Harness();
    await _pumpApp(tester, harness);
    await _openBlank(tester);
    await _typeHeadline(tester, 'Survives the crash');

    await tester.pump(const Duration(seconds: 3));
    expect(harness.autosave.records.keys, ['untitled.fluvie']);

    // The crash: the app goes away without any save or close.
    await tester.pumpWidget(const SizedBox());
    expect(harness.autosave.records.keys, ['untitled.fluvie']);

    // Next launch, same deck key: the recovery prompt offers the autosave.
    await _pumpApp(tester, harness);
    await _openBlank(tester);
    expect(find.text('Recover unsaved changes?'), findsOneWidget);
    expect(find.textContaining('just now'), findsOneWidget);

    await tester.tap(find.text('Recover'));
    await tester.pumpAndSettle();
    final ids = _document(tester).elementIdsInScene(0);
    expect(_document(tester).elementJson(ids.single)!['text'], 'Survives the crash');
    // Recovered means not saved: the file on disk never changed.
    expect(find.text('Unsaved'), findsOneWidget);

    // Save writes the file and clears the autosave; reopening stays quiet.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(harness.autosave.records, isEmpty);

    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    await _openBlank(tester);
    expect(find.text('Recover unsaved changes?'), findsNothing);
    expect(_document(tester).elementIdsInScene(0), isEmpty);
  });

  testWidgets('discarding the recovery deletes the autosave and opens the file', (tester) async {
    final harness = _Harness();
    harness.autosave.records['untitled.fluvie'] = AutosaveRecord(
      json: jsonEncode(_fileSpec),
      savedAt: DateTime.now(),
      digest: 'differs-from-blank',
    );
    await _pumpApp(tester, harness);
    await _openBlank(tester);
    expect(find.text('Recover unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(harness.autosave.records, isEmpty);
    expect(_document(tester).elementIdsInScene(0), isEmpty);
  });

  testWidgets('dismissing the prompt keeps the autosave and opens the file', (tester) async {
    final harness = _Harness();
    harness.autosave.records['untitled.fluvie'] = AutosaveRecord(
      json: jsonEncode(_fileSpec),
      savedAt: DateTime.now(),
      digest: 'differs-from-blank',
    );
    await _pumpApp(tester, harness);
    await _openBlank(tester);
    expect(find.text('Recover unsaved changes?'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Recover unsaved changes?'), findsNothing);
    expect(harness.autosave.records.keys, ['untitled.fluvie']);
    expect(_document(tester).elementIdsInScene(0), isEmpty);
  });

  testWidgets('an autosave matching the opened file never prompts', (tester) async {
    final harness = _Harness();
    final opened = EditorDocument.fromJson(
      jsonDecode(jsonEncode(_fileSpec)) as Map<String, Object?>,
    );
    harness.autosave.records['/decks/file.fluvie'] = AutosaveRecord(
      json: jsonEncode(_fileSpec),
      savedAt: DateTime.now(),
      digest: opened.documentDigest,
    );
    await _pumpApp(tester, harness);
    await _openFileForEdit(tester);
    expect(find.text('Recover unsaved changes?'), findsNothing);
    expect(find.byType(EditorCanvas), findsOneWidget);
  });

  testWidgets('a file open recovers under its path key', (tester) async {
    final harness = _Harness();
    const edited = {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'id': 'el-1',
              'type': 'Text',
              'text': 'edited and unsaved',
              'style': {'color': '#FFFFFF', 'fontSize': 40},
            },
          ],
        },
      ],
    };
    harness.autosave.records['/decks/file.fluvie'] = AutosaveRecord(
      json: jsonEncode(edited),
      savedAt: DateTime.now(),
      digest: 'differs',
    );
    await _pumpApp(tester, harness);
    await _openFileForEdit(tester);
    expect(find.text('Recover unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Recover'));
    await tester.pumpAndSettle();
    final ids = _document(tester).elementIdsInScene(0);
    expect(_document(tester).elementJson(ids.single)!['text'], 'edited and unsaved');
    expect(find.text('Unsaved'), findsOneWidget);
  });

  testWidgets('an unreadable autosave reads as absent', (tester) async {
    final harness = _Harness();
    harness.autosave.records['untitled.fluvie'] = AutosaveRecord(
      json: '{broken',
      savedAt: DateTime.now(),
      digest: 'x',
    );
    await _pumpApp(tester, harness);
    await _openBlank(tester);
    expect(find.text('Recover unsaved changes?'), findsNothing);
    expect(find.byType(EditorCanvas), findsOneWidget);
  });

  testWidgets('a broken store never blocks opening', (tester) async {
    final harness = _Harness();
    await _pumpApp(tester, harness, autosave: _BrokenStore());
    await _openBlank(tester);
    expect(find.text('Recover unsaved changes?'), findsNothing);
    expect(find.byType(EditorCanvas), findsOneWidget);
  });

  testWidgets('a session-media deck recovers whole: bytes, previews, document', (tester) async {
    final harness = _Harness();
    // A tiny valid PNG (1x1) so the recovered preview decodes for real.
    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    const mediaSpec = {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'id': 'el-1',
              'type': 'Image',
              'source': {'kind': 'bundle', 'value': 'media/photo.png'},
            },
          ],
        },
      ],
    };
    // The desktop sidecar bundle survived the crash with the bytes inside.
    harness.autosave.records['untitled.fluvie'] = AutosaveRecord(
      json: jsonEncode(mediaSpec),
      savedAt: DateTime.now(),
      digest: 'differs-from-blank',
    );
    harness.autosave.media['untitled.fluvie'] = {'media/photo.png': photo};

    await _pumpApp(tester, harness);
    await _openBlank(tester);
    expect(find.text('Recover unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Recover'));
    await tester.pumpAndSettle();

    // The document is the autosaved one and its preview builds — the canvas
    // mounts the bundle-sourced slide, which requires the restored bytes.
    final ids = _document(tester).elementIdsInScene(0);
    expect(_document(tester).elementJson(ids.single)!['type'], 'Image');
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(harness.session.bytesFor('media/photo.png'), photo);
    expect(BundleMedia.current, isNotNull);
    expect(BundleMedia.resolveMedia('media/photo.png'), isA<MemorySource>());
  });

  testWidgets('an autosave missing its media says so and cannot open unsafely', (tester) async {
    final harness = _Harness();
    const mediaSpec = {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'id': 'el-1',
              'type': 'Image',
              'source': {'kind': 'bundle', 'value': 'media/photo.png'},
            },
          ],
        },
      ],
    };
    // The web reality: the record survived in localStorage, the bytes did not.
    harness.autosave.records['untitled.fluvie'] = AutosaveRecord(
      json: jsonEncode(mediaSpec),
      savedAt: DateTime.now(),
      digest: 'differs-from-blank',
    );

    await _pumpApp(tester, harness);
    await _openBlank(tester);

    // The prompt names what is missing and offers no unsafe Recover.
    expect(find.textContaining('media/photo.png'), findsOneWidget);
    expect(find.text('Recover'), findsNothing);

    // Keep leaves the autosave for an open that has the bundle's media.
    await tester.tap(find.text('Keep autosave'));
    await tester.pumpAndSettle();
    expect(harness.autosave.records.keys, ['untitled.fluvie']);
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(_document(tester).elementIdsInScene(0), isEmpty);
  });

  testWidgets('a session already holding the media recovers normally', (tester) async {
    // The web path: reopening the bundle repopulated the session, so a plain
    // JSON autosave over the same media recovers fully.
    final harness = _Harness();
    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    await harness.session.adopt({'media/photo.png': photo});
    const mediaSpec = {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'id': 'el-1',
              'type': 'Image',
              'source': {'kind': 'bundle', 'value': 'media/photo.png'},
            },
          ],
        },
      ],
    };
    harness.autosave.records['untitled.fluvie'] = AutosaveRecord(
      json: jsonEncode(mediaSpec),
      savedAt: DateTime.now(),
      digest: 'differs-from-blank',
    );

    await _pumpApp(tester, harness);
    await _openBlank(tester);
    expect(find.text('Recover unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Recover'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(_document(tester).elementIdsInScene(0), hasLength(1));
  });

  testWidgets('discarding a media-less autosave deletes it', (tester) async {
    final harness = _Harness();
    const mediaSpec = {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'id': 'el-1',
              'type': 'Image',
              'source': {'kind': 'bundle', 'value': 'media/photo.png'},
            },
          ],
        },
      ],
    };
    harness.autosave.records['untitled.fluvie'] = AutosaveRecord(
      json: jsonEncode(mediaSpec),
      savedAt: DateTime.now(),
      digest: 'differs-from-blank',
    );

    await _pumpApp(tester, harness);
    await _openBlank(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(harness.autosave.records, isEmpty);
    expect(find.byType(EditorCanvas), findsOneWidget);
  });
}
