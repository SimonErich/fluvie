import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/loader/start_prefs_store_io.dart';

void main() {
  group('StartPrefs', () {
    test('round-trips through JSON', () {
      expect(StartPrefs.fromJson(const StartPrefs().toJson()).tipsDismissed, isFalse);
      expect(
        StartPrefs.fromJson(const StartPrefs(tipsDismissed: true).toJson()).tipsDismissed,
        isTrue,
      );
    });

    test('the codec tolerates garbage and foreign JSON', () {
      expect(decodeStartPrefs('').tipsDismissed, isFalse);
      expect(decodeStartPrefs('{not json').tipsDismissed, isFalse);
      expect(decodeStartPrefs('[1, 2]').tipsDismissed, isFalse);
      expect(decodeStartPrefs('{"tipsDismissed": "yes"}').tipsDismissed, isFalse);
      expect(decodeStartPrefs('{"tipsDismissed": true}').tipsDismissed, isTrue);
    });

    test('the encoder writes what the decoder reads', () {
      const prefs = StartPrefs(tipsDismissed: true);
      expect(decodeStartPrefs(encodeStartPrefs(prefs)).tipsDismissed, isTrue);
    });
  });

  group('IoStartPrefsStore', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('fluvie_start_prefs_test');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('saves and loads through its JSON file', () async {
      final store = IoStartPrefsStore(path: '${temp.path}/start_prefs.json');
      expect((await store.load()).tipsDismissed, isFalse);
      await store.save(const StartPrefs(tipsDismissed: true));
      final reloaded = IoStartPrefsStore(path: '${temp.path}/start_prefs.json');
      expect((await reloaded.load()).tipsDismissed, isTrue);
    });

    test('a corrupted file reads as the defaults', () async {
      final path = '${temp.path}/start_prefs.json';
      await File(path).writeAsString('{broken');
      expect((await IoStartPrefsStore(path: path).load()).tipsDismissed, isFalse);
    });

    test('the default path follows XDG_CONFIG_HOME, then HOME', () {
      final xdg = IoStartPrefsStore(environment: {'XDG_CONFIG_HOME': '/xdg'});
      expect(xdg.path, '/xdg/fluvie_slides/start_prefs.json');
      final home = IoStartPrefsStore(environment: {'HOME': '/home/me'});
      expect(home.path, '/home/me/.config/fluvie_slides/start_prefs.json');
      final bare = IoStartPrefsStore(environment: const {});
      expect(bare.path, './.config/fluvie_slides/start_prefs.json');
    });

    test('the platform store is the io store here', () {
      expect(platformStartPrefsStore(), isA<IoStartPrefsStore>());
      expect(StartPrefsStore.platform(), isA<IoStartPrefsStore>());
    });
  });
}
