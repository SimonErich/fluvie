import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slides/loader/recent_deck.dart';
import 'package:slides/loader/recent_decks_store.dart';
import 'package:slides/loader/recent_decks_store_io.dart';

RecentDeck _deck(String name, {String? path, int at = 0}) => RecentDeck(
  name: name,
  path: path,
  lastOpened: DateTime.fromMillisecondsSinceEpoch(at),
);

void main() {
  group('RecentDeck', () {
    test('round-trips through JSON, with and without a path', () {
      final withPath = _deck('a.fluvie', path: '/decks/a.fluvie', at: 1000);
      final parsed = RecentDeck.fromJson(withPath.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.name, 'a.fluvie');
      expect(parsed.path, '/decks/a.fluvie');
      expect(parsed.lastOpened, DateTime.fromMillisecondsSinceEpoch(1000));

      final webOnly = RecentDeck.fromJson(_deck('b.fluvie', at: 2000).toJson());
      expect(webOnly!.path, isNull);
    });

    test('rejects entries without a name', () {
      expect(RecentDeck.fromJson({'path': '/x'}), isNull);
      expect(RecentDeck.fromJson('junk'), isNull);
      expect(RecentDeck.fromJson(null), isNull);
    });

    test('the list codec tolerates garbage and skips junk entries', () {
      expect(decodeRecentDecks(null), isEmpty);
      expect(decodeRecentDecks(''), isEmpty);
      expect(decodeRecentDecks('{not json'), isEmpty);
      expect(decodeRecentDecks('{"an": "object"}'), isEmpty);
      final partial = decodeRecentDecks('[{"name": "ok.fluvie", "lastOpened": 5}, 7, {"x": 1}]');
      expect(partial, hasLength(1));
      expect(partial.single.name, 'ok.fluvie');
    });

    test('the list codec round-trips', () {
      final decks = [_deck('a.fluvie', path: '/a', at: 1), _deck('b.fluvie', at: 2)];
      final decoded = decodeRecentDecks(encodeRecentDecks(decks));
      expect(decoded.map((d) => d.name), ['a.fluvie', 'b.fluvie']);
      expect(decoded.first.path, '/a');
    });
  });

  group('upsertRecents', () {
    test('inserts newest first and dedupes by path', () {
      var list = upsertRecents(const [], _deck('a.fluvie', path: '/a', at: 1));
      list = upsertRecents(list, _deck('b.fluvie', path: '/b', at: 2));
      list = upsertRecents(list, _deck('a renamed.fluvie', path: '/a', at: 3));
      expect(list.map((d) => d.name), ['a renamed.fluvie', 'b.fluvie']);
    });

    test('dedupes by name when no path exists', () {
      var list = upsertRecents(const [], _deck('web.fluvie', at: 1));
      list = upsertRecents(list, _deck('web.fluvie', at: 2));
      expect(list, hasLength(1));
      expect(list.single.lastOpened, DateTime.fromMillisecondsSinceEpoch(2));
    });

    test('drops the replaced entry (a rename keys off the old identity)', () {
      var list = upsertRecents(const [], _deck('old.fluvie', at: 1));
      list = upsertRecents(list, _deck('new.fluvie', at: 2), replacing: _deck('old.fluvie', at: 1));
      expect(list.map((d) => d.name), ['new.fluvie']);
    });

    test('caps the list at eight entries', () {
      var list = const <RecentDeck>[];
      for (var i = 0; i < 10; i++) {
        list = upsertRecents(list, _deck('$i.fluvie', path: '/$i', at: i));
      }
      expect(list, hasLength(8));
      expect(list.first.name, '9.fluvie');
      expect(list.last.name, '2.fluvie');
    });
  });

  group('IoRecentDecksStore', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('fluvie_recents_test');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('records and loads through its JSON file', () async {
      final store = IoRecentDecksStore(path: '${temp.path}/recents.json');
      expect(await store.load(), isEmpty);
      await store.record(_deck('a.fluvie', path: '/a', at: 1));
      await store.record(_deck('b.fluvie', path: '/b', at: 2));
      final loaded = await IoRecentDecksStore(path: '${temp.path}/recents.json').load();
      expect(loaded.map((d) => d.name), ['b.fluvie', 'a.fluvie']);
    });

    test('replacing drops the old identity on disk too', () async {
      final store = IoRecentDecksStore(path: '${temp.path}/recents.json');
      await store.record(_deck('old.fluvie', path: '/old', at: 1));
      await store.record(
        _deck('renamed.fluvie', path: '/old', at: 2),
        replacing: _deck('old.fluvie', path: '/old', at: 1),
      );
      final loaded = await store.load();
      expect(loaded.map((d) => d.name), ['renamed.fluvie']);
    });

    test('a corrupted file reads as empty', () async {
      final path = '${temp.path}/recents.json';
      await File(path).writeAsString('{broken');
      expect(await IoRecentDecksStore(path: path).load(), isEmpty);
    });

    test('the default path follows XDG_CONFIG_HOME, then HOME', () {
      final xdg = IoRecentDecksStore(environment: {'XDG_CONFIG_HOME': '/xdg'});
      expect(xdg.path, '/xdg/fluvie_slides/recent_decks.json');
      final home = IoRecentDecksStore(environment: {'HOME': '/home/me'});
      expect(home.path, '/home/me/.config/fluvie_slides/recent_decks.json');
      final bare = IoRecentDecksStore(environment: const {});
      expect(bare.path, './.config/fluvie_slides/recent_decks.json');
    });

    test('the platform store is the io store here', () {
      expect(platformRecentDecksStore(), isA<IoRecentDecksStore>());
    });
  });
}
