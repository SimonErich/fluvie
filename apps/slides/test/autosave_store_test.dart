import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';
import 'package:slides/loader/autosave_store_io.dart';
import 'package:slides/loader/fluvie_bundle.dart';

AutosaveRecord _record(String json, {int at = 1000}) => AutosaveRecord(
  json: json,
  savedAt: DateTime.fromMillisecondsSinceEpoch(at),
  digest: 'digest-of-$json',
);

void main() {
  group('autosaveFileName', () {
    test('maps any key to a fixed-shape sidecar file name', () {
      expect(autosaveFileName('/decks/mine.fluvie'), matches(RegExp(r'^[0-9a-f]{16}\.json$')));
      expect(autosaveFileName('untitled.fluvie'), matches(RegExp(r'^[0-9a-f]{16}\.json$')));
    });

    test('is stable per key and distinct across keys', () {
      expect(autosaveFileName('/decks/a.fluvie'), autosaveFileName('/decks/a.fluvie'));
      expect(
        autosaveFileName('/decks/a.fluvie'),
        isNot(autosaveFileName('/decks/b.fluvie')),
      );
    });
  });

  group('IoAutosaveStore', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('fluvie_autosave_test');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    IoAutosaveStore store() => IoAutosaveStore(directory: '${temp.path}/autosave');

    test('write, read, and clear round-trip through sidecar files', () async {
      expect(await store().read('/decks/mine.fluvie'), isNull);
      await store().write('/decks/mine.fluvie', _record('{"a": 1}'));
      final read = await store().read('/decks/mine.fluvie');
      expect(read!.record.json, '{"a": 1}');
      expect(read.record.digest, 'digest-of-{"a": 1}');
      expect(read.record.savedAt, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(read.media, isEmpty);
      await store().clear('/decks/mine.fluvie');
      expect(await store().read('/decks/mine.fluvie'), isNull);
    });

    test('keys keep separate sidecars', () async {
      await store().write('/decks/a.fluvie', _record('{"a": 1}'));
      await store().write('untitled.fluvie', _record('{"b": 2}'));
      expect((await store().read('/decks/a.fluvie'))!.record.json, '{"a": 1}');
      expect((await store().read('untitled.fluvie'))!.record.json, '{"b": 2}');
      await store().clear('/decks/a.fluvie');
      expect(await store().read('/decks/a.fluvie'), isNull);
      expect((await store().read('untitled.fluvie'))!.record.json, '{"b": 2}');
    });

    test('a write with session media becomes one bundle sidecar, bytes intact', () async {
      final photo = Uint8List.fromList(const [137, 80, 78, 71]);
      final io = store();
      await io.write(
        '/decks/mine.fluvie',
        _record('{"a": 1}'),
        media: {'media/photo.png': photo},
      );

      // The one sidecar file is now a sniffable zip, the .fluvie bundle way.
      expect(isZipBytes(await File(io.pathFor('/decks/mine.fluvie')).readAsBytes()), isTrue);

      final read = await io.read('/decks/mine.fluvie');
      expect(read!.record.json, '{"a": 1}');
      expect(read.record.digest, 'digest-of-{"a": 1}');
      expect(read.media, {'media/photo.png': photo});
    });

    test('a later media-less write returns the sidecar to plain JSON', () async {
      final io = store();
      await io.write(
        'untitled.fluvie',
        _record('{"a": 1}'),
        media: {
          'media/photo.png': Uint8List.fromList(const [1]),
        },
      );
      await io.write('untitled.fluvie', _record('{"b": 2}'));
      expect(isZipBytes(await File(io.pathFor('untitled.fluvie')).readAsBytes()), isFalse);
      final read = await io.read('untitled.fluvie');
      expect(read!.record.json, '{"b": 2}');
      expect(read.media, isEmpty);
    });

    test('a corrupted bundle sidecar reads as absent', () async {
      final io = store();
      await io.write(
        'untitled.fluvie',
        _record('{}'),
        media: {
          'media/x.png': Uint8List.fromList(const [1]),
        },
      );
      await File(io.pathFor('untitled.fluvie')).writeAsString('PK broken');
      expect(await io.read('untitled.fluvie'), isNull);
    });

    test('a corrupted sidecar reads as absent', () async {
      final io = store();
      await io.write('mine.fluvie', _record('{}'));
      await File(io.pathFor('mine.fluvie')).writeAsString('{broken');
      expect(await io.read('mine.fluvie'), isNull);
    });

    test('clearing a key that was never written is quiet', () async {
      await store().clear('never.fluvie');
      expect(await store().read('never.fluvie'), isNull);
    });

    test('an unwritable location degrades to no autosave, never a throw', () async {
      // A file where the directory should go blocks its creation.
      await File('${temp.path}/blocker').writeAsString('in the way');
      final blocked = IoAutosaveStore(directory: '${temp.path}/blocker/autosave');
      await blocked.write('mine.fluvie', _record('{}'));
      expect(await blocked.read('mine.fluvie'), isNull);
    });

    test('the sidecars live under the config directory, not next to the deck', () {
      final xdg = IoAutosaveStore(environment: const {'XDG_CONFIG_HOME': '/xdg'});
      expect(xdg.directory, '/xdg/fluvie_slides/autosave');
      final home = IoAutosaveStore(environment: const {'HOME': '/home/me'});
      expect(home.directory, '/home/me/.config/fluvie_slides/autosave');
      final bare = IoAutosaveStore(environment: const {});
      expect(bare.directory, './.config/fluvie_slides/autosave');
      expect(
        xdg.pathFor('/decks/mine.fluvie'),
        '/xdg/fluvie_slides/autosave/${autosaveFileName('/decks/mine.fluvie')}',
      );
    });

    test('the platform store is the io store here', () {
      expect(AutosaveStore.platform(), isA<IoAutosaveStore>());
    });
  });
}
