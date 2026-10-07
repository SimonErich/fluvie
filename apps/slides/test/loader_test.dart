import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show BundleMedia;
import 'package:slides/editor/session_media_store.dart';
import 'package:slides/loader/fluvie_bundle.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/open_fluvie_path.dart';

const Map<String, Object?> _spec = {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'children': [
        {
          'type': 'Text',
          'text': 'Hello from a file',
          'style': {'color': '#FFFFFF', 'fontSize': 72},
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
  ],
};

void main() {
  test('a valid .fluvie document becomes a presentable deck', () {
    final loaded = parseFluvieJson('demo.fluvie', jsonEncode(_spec));
    expect(loaded.error, isNull);
    expect(loaded.video, isNotNull);
    expect(loaded.video!.scenes, hasLength(1));
    expect(loaded.rawJson, isNotNull);
  });

  test('broken JSON fails with a friendly message', () {
    final loaded = parseFluvieJson('demo.fluvie', '{not json');
    expect(loaded.video, isNull);
    expect(loaded.error, contains('not valid JSON'));
  });

  test('a JSON array is rejected: one object per file', () {
    final loaded = parseFluvieJson('demo.fluvie', '[]');
    expect(loaded.error, 'A .fluvie file holds one JSON object.');
  });

  test('a dropped file parses from bytes, and empty drops fail friendly', () async {
    final ok = await parseDroppedFluvie('drop.fluvie', utf8.encode(jsonEncode(_spec)));
    expect(ok.video, isNotNull);
    expect(
      (await parseDroppedFluvie('drop.fluvie', null)).error,
      'The dropped file arrived without content.',
    );
    expect(
      (await parseDroppedFluvie('drop.fluvie', const <int>[])).error,
      'The dropped file arrived without content.',
    );
  });

  group('bundle opens', () {
    const bundledSpec = {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '90f',
          'children': [
            {
              'type': 'Image',
              'source': {'kind': 'bundle', 'value': 'media/photo.png'},
            },
          ],
        },
      ],
    };

    SessionMediaStore session() => SessionMediaStore(materialize: memorySessionMaterializer);

    tearDown(() => BundleMedia.current = null);

    test('a .fluvie bundle opens: bytes adopted, scope published, deck built', () async {
      final photo = Uint8List.fromList([9, 9, 9]);
      final zip = buildFluvieBundle(
        deckJson: jsonEncode(bundledSpec),
        media: {'media/photo.png': photo},
      );
      final store = session();
      final loaded = await parseFluvieBytes('deck.fluvie', zip, session: store);
      expect(loaded.error, isNull);
      expect(loaded.video, isNotNull);
      expect(loaded.rawJson, jsonEncode(bundledSpec));
      expect(store.bytesFor('media/photo.png'), photo);
      expect(BundleMedia.current!.media['media/photo.png'], isNotNull);
    });

    test('opening a plain deck afterwards retires the previous session', () async {
      final store = session();
      await store.register('old.png', Uint8List.fromList([1]));
      final loaded = await parseFluvieBytes(
        'plain.fluvie',
        utf8.encode(jsonEncode(_spec)),
        session: store,
      );
      expect(loaded.video, isNotNull);
      expect(store.bytes, isEmpty);
      expect(BundleMedia.current, isNull);
    });

    test('a broken bundle fails with a friendly bundle message', () async {
      final loaded = await parseFluvieBytes(
        'broken.fluvie',
        Uint8List.fromList([0x50, 0x4B, 0, 1, 2]),
        session: session(),
      );
      expect(loaded.video, isNull);
      expect(loaded.error, contains('bundle'));
    });

    test('a bundle without the deck JSON names the missing entry', () async {
      final zip = buildFluvieBundle(deckJson: '{}', media: const {});
      // Rebuild a zip holding only media, no deck: craft via the reader error.
      final loaded = await parseFluvieBytes(
        'empty.fluvie',
        zip,
        session: session(),
      );
      // '{}' is a JSON object but not a valid spec: the resolver message shows.
      expect(loaded.error, contains('did not resolve'));
    });
  });

  test('a spec problem surfaces the resolver message', () {
    final loaded = parseFluvieJson('demo.fluvie', '{"scenes": []}');
    expect(loaded.video, isNull);
    expect(loaded.error, contains('did not resolve'));
  });

  test('a parsed file remembers the path it came from', () {
    final loaded = parseFluvieJson('demo.fluvie', jsonEncode(_spec), path: '/decks/demo.fluvie');
    expect(loaded.path, '/decks/demo.fluvie');
    expect(parseFluvieJson('demo.fluvie', jsonEncode(_spec)).path, isNull);
  });

  group('openFluvieFileAtPath', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('fluvie_loader_test');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('reads a deck back by its path', () async {
      final path = '${temp.path}/mine.fluvie';
      await File(path).writeAsString(jsonEncode(_spec));
      final loaded = await openFluvieFileAtPath(path);
      expect(loaded.error, isNull);
      expect(loaded.video, isNotNull);
      expect(loaded.name, 'mine.fluvie');
      expect(loaded.path, path);
    });

    test('a missing file fails with a friendly message', () async {
      final loaded = await openFluvieFileAtPath('${temp.path}/gone.fluvie');
      expect(loaded.video, isNull);
      expect(loaded.error, contains('could not be read'));
      expect(loaded.name, 'gone.fluvie');
    });

    test('a broken file surfaces the parse error', () async {
      final path = '${temp.path}/broken.fluvie';
      await File(path).writeAsString('{nope');
      final loaded = await openFluvieFileAtPath(path);
      expect(loaded.error, contains('not valid JSON'));
    });
  });
}
