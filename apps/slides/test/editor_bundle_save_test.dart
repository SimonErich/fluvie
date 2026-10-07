import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show BundleMedia;
import 'package:fluvie_editor/fluvie_editor.dart' show EditorDocument;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/loader/fluvie_bundle.dart';
import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:slides/loader/open_fluvie_file.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

Map<String, Object?> _bundledDeck() => {
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
          'source': {'kind': 'bundle', 'value': 'media/photo.png'},
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
        },
      ],
    },
  ],
};

Map<String, Object?> _plainDeck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {'duration': '60f', 'layout': 'canvas', 'children': <Object?>[]},
  ],
};

/// A tiny valid PNG (1x1, opaque) so the preview decodes the session bytes.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

final class _FakeSaver implements FluvieFileSaver {
  final List<({String name, String contents, bool pickNew})> calls = [];
  final List<({String name, List<int> bytes, bool pickNew})> bundleCalls = [];

  @override
  String? targetPath;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    calls.add((name: suggestedName, contents: contents, pickNew: pickNew));
    targetPath = '/decks/$suggestedName';
    return suggestedName;
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async {
    calls.add((name: suggestedName, contents: contents, pickNew: true));
    return suggestedName;
  }

  @override
  Future<String?> saveCopyBytes({required String suggestedName, required List<int> bytes}) async =>
      null;

  @override
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  }) async {
    bundleCalls.add((name: suggestedName, bytes: bytes, pickNew: pickNew));
    targetPath = '/decks/$suggestedName';
    return suggestedName;
  }
}

final class _Harness {
  _Harness(this.saver, this.session);
  final _FakeSaver saver;
  final SessionMediaStore session;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Map<String, Object?>? deck,
  bool withSessionPhoto = true,
  bool dropSaveBytes = false,
}) async {
  useDesktopSurface(tester);
  final session = SessionMediaStore(materialize: memorySessionMaterializer);
  addTearDown(() {
    session.clear();
    BundleMedia.current = null;
  });
  if (withSessionPhoto) {
    expect(await session.register('photo.png', _pngBytes), 'media/photo.png');
  }
  if (dropSaveBytes) {
    // The preview scope stays published (the canvas builds), but the
    // screen's own store no longer holds the bytes a bundle save reads.
    final scope = BundleMedia.current;
    session.clear();
    BundleMedia.current = scope;
  }
  final saver = _FakeSaver();
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(deck ?? _bundledDeck()),
        title: 'mine.fluvie',
        onClose: () {},
        saver: saver,
        autosave: MemoryAutosaveStore(),
        sessionMedia: session,
      ),
    ),
  );
  await tester.pump();
  return _Harness(saver, session);
}

/// Opens the File menu, where Save as and Save a copy now live.
Future<void> _openFileMenu(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a bin-only asset survives saving and reopening a project bundle', (tester) async {
    final deck = _plainDeck()
      ..['editor'] = {
        'media': [
          {
            'id': 'media-1',
            'name': 'photo.png',
            'kind': 'image',
            'source': {'kind': 'bundle', 'value': 'media/photo.png'},
            'folder': 'Unplaced',
          },
        ],
      };
    final harness = await _pump(tester, deck: deck);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save imported media?'), findsOneWidget);
    await tester.tap(find.text('Save bundle'));
    await tester.pumpAndSettle();
    final reopened = readFluvieBundle(harness.saver.bundleCalls.single.bytes);
    expect(reopened.media['media/photo.png'], _pngBytes);
    expect(jsonDecode(reopened.deckJson), EditorDocument.fromJson(deck).toJson());
    expect(harness.saver.calls, isEmpty);
  });

  testWidgets('a deck without session media saves plain JSON with no dialog', (tester) async {
    final harness = await _pump(tester, deck: _plainDeck(), withSessionPhoto: false);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls, hasLength(1));
    expect(harness.saver.bundleCalls, isEmpty);
    expect(find.text('Save imported media?'), findsNothing);
  });

  testWidgets('Save bundle packs the deck JSON plus the session bytes', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save imported media?'), findsOneWidget);

    await tester.tap(find.text('Save bundle'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls, isEmpty);
    final call = harness.saver.bundleCalls.single;
    expect(call.name, 'mine.fluvie');
    final read = readFluvieBundle(call.bytes);
    expect(jsonDecode(read.deckJson), EditorDocument.fromJson(_bundledDeck()).toJson());
    expect(read.media['media/photo.png'], _pngBytes);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('Save JSON only warns once, and the suppression sticks per deck', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't ask again for this deck"));
    await tester.pump();
    await tester.tap(find.text('Save JSON only'));
    await tester.pumpAndSettle();

    expect(harness.saver.bundleCalls, isEmpty);
    final saved = jsonDecode(harness.saver.calls.single.contents) as Map<String, Object?>;
    final editor = saved['editor']! as Map<String, Object?>;
    expect((editor['deck']! as Map<String, Object?>)['mediaSave'], 'json');

    // Suppressed: the next save writes plain JSON with no dialog.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save imported media?'), findsNothing);
    expect(harness.saver.calls, hasLength(2));
    expect(harness.saver.bundleCalls, isEmpty);
  });

  testWidgets('a remembered bundle choice saves bundles silently', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't ask again for this deck"));
    await tester.pump();
    await tester.tap(find.text('Save bundle'));
    await tester.pumpAndSettle();
    expect(harness.saver.bundleCalls, hasLength(1));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save imported media?'), findsNothing);
    expect(harness.saver.bundleCalls, hasLength(2));
    expect(harness.saver.calls, isEmpty);
  });

  testWidgets('Cancel keeps everything unsaved', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls, isEmpty);
    expect(harness.saver.bundleCalls, isEmpty);
  });

  testWidgets('a bundle save with missing session bytes fails visibly', (tester) async {
    final harness = await _pump(tester, dropSaveBytes: true);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save bundle'));
    await tester.pumpAndSettle();
    expect(harness.saver.bundleCalls, isEmpty);
    expect(find.textContaining('media/photo.png'), findsOneWidget);
  });

  testWidgets('Save a copy warns before writing a media-less JSON copy', (tester) async {
    final harness = await _pump(tester);
    await _openFileMenu(tester);
    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('will not carry'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls, isEmpty);

    await _openFileMenu(tester);
    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save copy anyway'));
    await tester.pumpAndSettle();
    expect(harness.saver.calls, hasLength(1));
  });

  testWidgets('round-trip: imported bytes reopen identical through the bundle', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save bundle'));
    await tester.pumpAndSettle();
    final bytes = harness.saver.bundleCalls.single.bytes;

    final reopenSession = SessionMediaStore(materialize: memorySessionMaterializer);
    final loaded = await parseFluvieBytes('mine.fluvie', bytes, session: reopenSession);
    expect(loaded.error, isNull);
    final reopened = EditorDocument.fromJson(
      jsonDecode(loaded.rawJson!) as Map<String, Object?>,
    );
    // The spec JSON is identical, the digest machine-stable, the bytes intact.
    expect(reopened.toJson(), EditorDocument.fromJson(_bundledDeck()).toJson());
    expect(reopened.renderDigest, EditorDocument.fromJson(_bundledDeck()).renderDigest);
    expect(reopenSession.bytesFor('media/photo.png'), _pngBytes);
  });
}
