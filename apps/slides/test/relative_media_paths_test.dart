import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show MediaFileBase;
import 'package:fluvie_editor/fluvie_editor.dart' show EditorDocument;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/relative_media_paths.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'file', 'value': '/decks/media/bed.mp3'},
    },
  ],
  'editor': {
    'editorSchema': 1,
    'media': [
      {
        'id': 'media-1',
        'name': 'photo.png',
        'kind': 'image',
        'source': {'kind': 'file', 'value': '/decks/media/photo.png'},
      },
      {
        'id': 'media-2',
        'name': 'bed.mp3',
        'kind': 'audio',
        'source': {'kind': 'file', 'value': '/decks/media/bed.mp3'},
      },
    ],
  },
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-in',
          'type': 'Image',
          'source': {'kind': 'file', 'value': '/decks/media/photo.png'},
          'transform': {'x': 0.3, 'y': 0.4, 'w': 0.3, 'h': 0.3},
        },
        {
          'id': 'el-out',
          'type': 'Clip',
          'source': {'kind': 'file', 'value': '/elsewhere/broll.mp4'},
          'poster': {'kind': 'file', 'value': '/decks/media/poster.png'},
        },
      ],
    },
  ],
};

final class _FakeSaver implements FluvieFileSaver {
  final List<String> contents = [];

  @override
  String? targetPath;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    this.contents.add(contents);
    targetPath = '/decks/mine.fluvie';
    return 'mine.fluvie';
  }

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

void main() {
  tearDown(() => MediaFileBase.current = null);

  group('directoryOfPath', () {
    test('takes the folder off a file path, either separator', () {
      expect(directoryOfPath('/decks/mine.fluvie'), '/decks');
      expect(directoryOfPath(r'C:\decks\mine.fluvie'), r'C:\decks');
      expect(directoryOfPath('mine.fluvie'), isNull);
    });
  });

  group('deckJsonWithRelativeMediaPaths', () {
    test('rewrites file media under the document directory to relative', () {
      final rewritten = deckJsonWithRelativeMediaPaths(_deck(), documentDirectory: '/decks');
      final children =
          ((rewritten['scenes']! as List)[0]! as Map<String, Object?>)['children']! as List;
      expect((children[0]! as Map<String, Object?>)['source'], {
        'kind': 'file',
        'value': 'media/photo.png',
      });
      // A source outside the folder stays absolute; its poster inside goes
      // relative.
      expect((children[1]! as Map<String, Object?>)['source'], {
        'kind': 'file',
        'value': '/elsewhere/broll.mp4',
      });
      expect((children[1]! as Map<String, Object?>)['poster'], {
        'kind': 'file',
        'value': 'media/poster.png',
      });
    });

    test('never touches audio sources: the spec wants them absolute', () {
      final rewritten = deckJsonWithRelativeMediaPaths(_deck(), documentDirectory: '/decks');
      expect((rewritten['audio']! as List)[0], {
        'kind': 'music',
        'source': {'kind': 'file', 'value': '/decks/media/bed.mp3'},
      });
    });

    test('rewrites image and video store entries but not audio ones', () {
      final rewritten = deckJsonWithRelativeMediaPaths(_deck(), documentDirectory: '/decks');
      final media = (rewritten['editor']! as Map<String, Object?>)['media']! as List;
      expect((media[0]! as Map<String, Object?>)['source'], {
        'kind': 'file',
        'value': 'media/photo.png',
      });
      expect((media[1]! as Map<String, Object?>)['source'], {
        'kind': 'file',
        'value': '/decks/media/bed.mp3',
      });
    });

    test('re-anchors an already-relative value through the load base', () {
      final json = _deck();
      ((((json['scenes']! as List)[0]! as Map<String, Object?>)['children']! as List)[0]!
          as Map<String, Object?>)['source'] = {
        'kind': 'file',
        'value': 'media/photo.png',
      };
      // Saved into a different folder: the value absolutizes against the
      // base it was loaded under, and /old/media is not under /new.
      final rewritten = deckJsonWithRelativeMediaPaths(
        json,
        documentDirectory: '/new',
        base: '/old',
      );
      final children =
          ((rewritten['scenes']! as List)[0]! as Map<String, Object?>)['children']! as List;
      expect((children[0]! as Map<String, Object?>)['source'], {
        'kind': 'file',
        'value': '/old/media/photo.png',
      });
    });

    test('a relative value with no base stays untouched', () {
      final json = _deck();
      ((((json['scenes']! as List)[0]! as Map<String, Object?>)['children']! as List)[0]!
          as Map<String, Object?>)['source'] = {
        'kind': 'file',
        'value': 'media/photo.png',
      };
      final rewritten = deckJsonWithRelativeMediaPaths(json, documentDirectory: '/decks');
      final children =
          ((rewritten['scenes']! as List)[0]! as Map<String, Object?>)['children']! as List;
      expect((children[0]! as Map<String, Object?>)['source'], {
        'kind': 'file',
        'value': 'media/photo.png',
      });
    });

    test('is a fixed point: rewriting its own output changes nothing', () {
      final once = deckJsonWithRelativeMediaPaths(_deck(), documentDirectory: '/decks');
      final twice = deckJsonWithRelativeMediaPaths(
        once,
        documentDirectory: '/decks',
        base: '/decks',
      );
      expect(twice, once);
    });
  });

  group('opening a document', () {
    test('sets the media file base to the document folder', () async {
      final deck = await parseFluvieBytes(
        'mine.fluvie',
        utf8.encode(jsonEncode(_deck())),
        path: '/decks/mine.fluvie',
      );
      expect(deck.error, isNull);
      expect(MediaFileBase.current, '/decks');
    });

    test('clears the base when the platform knows no path', () async {
      MediaFileBase.current = '/stale';
      final deck = await parseFluvieBytes('mine.fluvie', utf8.encode(jsonEncode(_deck())));
      expect(deck.error, isNull);
      expect(MediaFileBase.current, isNull);
    });

    test('a relative-path deck opened from its folder parses and resolves', () async {
      final relative = deckJsonWithRelativeMediaPaths(_deck(), documentDirectory: '/decks');
      final deck = await parseFluvieBytes(
        'mine.fluvie',
        utf8.encode(jsonEncode(relative)),
        path: '/decks/mine.fluvie',
      );
      expect(deck.error, isNull);
      expect(deck.video, isNotNull);
    });
  });

  group('saving on the desktop', () {
    testWidgets('rewrites paths under the target folder and stays stable', (tester) async {
      useDesktopSurface(tester);
      final saver = _FakeSaver();
      await tester.pumpWidget(
        OiApp(
          title: 'test',
          theme: OiThemeData.dark(),
          home: EditorScreen(
            document: EditorDocument.fromJson(_deck()),
            title: 'mine.fluvie',
            onClose: () {},
            saver: saver,
            autosave: MemoryAutosaveStore(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The first save learns the target from the dialog, then immediately
      // settles the file with the rewritten paths.
      expect(saver.contents, hasLength(2));
      final settled = jsonDecode(saver.contents[1]) as Map<String, Object?>;
      final children =
          ((settled['scenes']! as List)[0]! as Map<String, Object?>)['children']! as List;
      expect((children[0]! as Map<String, Object?>)['source'], {
        'kind': 'file',
        'value': 'media/photo.png',
      });
      expect((children[1]! as Map<String, Object?>)['source'], {
        'kind': 'file',
        'value': '/elsewhere/broll.mp4',
      });
      expect((settled['audio']! as List)[0], {
        'kind': 'music',
        'source': {'kind': 'file', 'value': '/decks/media/bed.mp3'},
      });

      // A known target rewrites up front: one write, identical contents —
      // save and reopen never churn the file.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saver.contents, hasLength(3));
      expect(saver.contents[2], saver.contents[1]);

      // The reopened document produces the same render digest the saved
      // form carries.
      final reopened = await parseFluvieBytes(
        'mine.fluvie',
        utf8.encode(saver.contents[1]),
        path: '/decks/mine.fluvie',
      );
      expect(reopened.error, isNull);
      final savedDoc = EditorDocument.fromJson(settled);
      final reopenedDoc = EditorDocument.fromJson(parseRawJson(reopened.rawJson!));
      expect(reopenedDoc.renderDigest, savedDoc.renderDigest);
    });
  });
}
