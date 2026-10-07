import 'dart:async' show Completer;
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas, EditorDocument;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';
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
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        {
          'id': 'el-box',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
      ],
    },
  ],
};

final class _FakeSaver implements FluvieFileSaver {
  String? nextName = 'mine.fluvie';

  /// When set, saves stall on it (how the in-flight indicator is observed).
  Completer<void>? gate;

  @override
  String? targetPath;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    if (gate case final gate?) await gate.future;
    if (nextName != null) targetPath = '/decks/$nextName';
    return nextName;
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async {
    if (gate case final gate?) await gate.future;
    return nextName;
  }

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
  final MemoryAutosaveStore store = MemoryAutosaveStore();
  final _FakeSaver saver = _FakeSaver();
  int closed = 0;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AutosaveStore? store,
  String? savedDigest,
  Map<String, Object?>? deck,
  SessionMediaStore? sessionMedia,
}) async {
  useDesktopSurface(tester);
  final harness = _Harness();
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(deck ?? _deck()),
        title: 'mine.fluvie',
        onClose: () => harness.closed++,
        saver: harness.saver,
        autosave: store ?? harness.store,
        savedDigest: savedDigest,
        sessionMedia: sessionMedia,
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _edit(WidgetTester tester) async {
  final canvas = tester.getRect(find.byType(EditorCanvas));
  const size = Size(320, 180);
  const margin = 48.0;
  final scale = math.min(
    (canvas.width - 2 * margin) / size.width,
    (canvas.height - 2 * margin) / size.height,
  );
  final origin = canvas.center - Offset(size.width / 2 * scale, size.height / 2 * scale);
  await tester.tapAt(origin + const Offset(80, 90) * scale);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pump();
}

/// Opens the File menu, where Save as and Save a copy now live.
Future<void> _openFileMenu(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an edit autosaves after the debounce, under the title key', (tester) async {
    final harness = await _pump(tester);
    await _edit(tester);
    expect(find.text('Unsaved'), findsOneWidget);
    expect(harness.store.records, isEmpty);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final record = harness.store.records['mine.fluvie']!;
    final document = EditorDocument.fromJson(jsonDecode(record.json) as Map<String, Object?>);
    expect(record.digest, document.documentDigest);
    expect(find.text('Autosaved just now'), findsOneWidget);
  });

  testWidgets('a deck referencing session media autosaves its bytes too', (tester) async {
    // A tiny valid PNG (1x1) so the preview decodes the session bytes.
    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final session = SessionMediaStore(materialize: memorySessionMaterializer);
    addTearDown(session.clear);
    await session.adopt({'media/photo.png': photo});
    final deck = _deck();
    (((deck['scenes']! as List).first as Map<String, Object?>)['children']! as List).add({
      'id': 'el-img',
      'type': 'Image',
      'source': {'kind': 'bundle', 'value': 'media/photo.png'},
      'transform': {'x': 0.75, 'y': 0.5, 'w': 0.2, 'h': 0.2},
    });
    final harness = await _pump(tester, deck: deck, sessionMedia: session);
    await _edit(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(harness.store.records.keys, ['mine.fluvie']);
    expect(harness.store.media['mine.fluvie'], {'media/photo.png': photo});
  });

  testWidgets('save clears the autosave and retargets it to the saved path', (tester) async {
    final harness = await _pump(tester);
    await _edit(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(harness.store.records.keys, ['mine.fluvie']);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(harness.store.records, isEmpty);
    expect(find.text('Saved'), findsOneWidget);

    await _edit(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(harness.store.records.keys, ['/decks/mine.fluvie']);
  });

  testWidgets('closing with Discard clears the autosave', (tester) async {
    final harness = await _pump(tester);
    await _edit(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(harness.store.records, isNotEmpty);

    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(harness.closed, 1);
    expect(harness.store.records, isEmpty);
  });

  testWidgets('a clean close flushes the pending clear (undo back to saved)', (tester) async {
    final harness = await _pump(tester);
    await _edit(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(harness.store.records, isNotEmpty);

    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pump();
    // Close before the debounce would have cleared the stale record.
    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    expect(harness.closed, 1);
    expect(harness.store.records, isEmpty);
  });

  testWidgets('Present flushes the pending autosave immediately', (tester) async {
    final harness = await _pump(tester);
    await _edit(tester);
    expect(harness.store.records, isEmpty);

    await tester.tap(find.text('Present'));
    await tester.pump();
    await tester.pump();
    expect(harness.store.records.keys, ['mine.fluvie']);
  });

  testWidgets('a save in flight shows quiet progress', (tester) async {
    final harness = await _pump(tester);
    await _edit(tester);
    harness.saver.gate = Completer<void>();

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    harness.saver.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    // Save a copy shows the same affordance without retargeting anything.
    harness.saver.gate = Completer<void>();
    await _openFileMenu(tester);
    await tester.tap(find.text('Save a copy'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    harness.saver.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a broken store never breaks editing', (tester) async {
    await _pump(tester, store: _BrokenStore());
    await _edit(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Unsaved'), findsOneWidget);

    // The discard path swallows the broken clear too.
    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
  });

  testWidgets('a recovered document opens unsaved against the file digest', (tester) async {
    await _pump(tester, savedDigest: 'the-file-on-disk');
    expect(find.text('Unsaved'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });
}
