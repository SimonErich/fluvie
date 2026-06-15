import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/encoding/frame_cache.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fluvie_frame_cache_test_');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  Uint8List bytes(int seed) => Uint8List.fromList(List.generate(16, (i) => (seed + i) % 256));

  group('FrameCache', () {
    test('a miss returns null', () async {
      final cache = FrameCache(root);
      expect(await cache.lookup(cache.frameKey('digest', 0)), isNull);
    });

    test('store/lookup round-trips the bytes', () async {
      final cache = FrameCache(root);
      final key = cache.frameKey('digest', 0);

      await cache.store(key, bytes(7));

      expect(await cache.lookup(key), bytes(7));
    });

    test('distinct frames get distinct keys', () {
      final cache = FrameCache(root);
      expect(cache.frameKey('digest', 0), isNot(cache.frameKey('digest', 1)));
    });

    test('keys are hex and therefore path-safe', () {
      final cache = FrameCache(root);
      expect(cache.frameKey('digest', 3), matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('entries persist across FrameCache instances on the same root', () async {
      final first = FrameCache(root);
      final key = first.frameKey('digest', 5);
      await first.store(key, bytes(5));

      final second = FrameCache(root);

      expect(await second.lookup(key), bytes(5));
    });

    test('lookup rejects a path-escaping key', () async {
      final cache = FrameCache(root);
      await expectLater(() => cache.lookup('../escape'), throwsArgumentError);
    });

    test('store rejects a path-escaping key', () async {
      final cache = FrameCache(root);
      await expectLater(() => cache.store('../escape', bytes(1)), throwsArgumentError);
    });

    test('rejects keys with the wrong case or shape (ABCDEF)', () async {
      final cache = FrameCache(root);
      await expectLater(() => cache.lookup('ABCDEF'), throwsArgumentError);
      await expectLater(() => cache.store('ABCDEF', bytes(1)), throwsArgumentError);
    });

    test('differing digests are isolated', () async {
      final cache = FrameCache(root);
      await cache.store(cache.frameKey('digest-a', 0), bytes(1));

      expect(await cache.lookup(cache.frameKey('digest-b', 0)), isNull);
    });
  });

  group('FrameCache.defaultRoot', () {
    test('is the shared fluvie_frame_cache directory under system temp', () {
      expect(FrameCache.defaultRoot().path, '${Directory.systemTemp.path}/fluvie_frame_cache');
    });
  });

  group('frameCacheProvider', () {
    test('defaults to the shared system-temp root', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cache = container.read(frameCacheProvider);

      expect(cache.root.path, FrameCache.defaultRoot().path);
    });
  });
}
