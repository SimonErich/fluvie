// The persistent clip-frame cache: a content-addressed store of extracted clip
// frames under the user cache directory, so an unchanged clip is decoded once
// ever instead of once per run. These cover the key (the decode dimensions and
// decoder are part of it, or a preview's proxy raster would be served to a
// full-resolution render), the truncated-entry miss, and the size bound.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/media/runtime/clip_frame_cache.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fluvie_clip_frame_cache_test_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });

  ClipFrameCache cacheAt({int maxBytes = ClipFrameCache.defaultMaxBytes}) =>
      ClipFrameCache(Directory('${root.path}/clip_frames'), maxBytes: maxBytes);

  Uint8List rgba(int pixels, int seed) =>
      Uint8List(pixels * 4)..fillRange(0, pixels * 4, seed % 256);

  group('clipKey', () {
    test('is 16 hex characters, so it is path-safe', () {
      final key = cacheAt().clipKey(contentHash: 'abc123', width: 1920, height: 1080);
      expect(key, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('the same content, size, and decoder key the same', () {
      final cache = cacheAt();
      expect(
        cache.clipKey(contentHash: 'abc', width: 720, height: 404, decoder: 'libvpx-vp9'),
        cache.clipKey(contentHash: 'abc', width: 720, height: 404, decoder: 'libvpx-vp9'),
      );
    });

    test('different content keys apart', () {
      final cache = cacheAt();
      expect(
        cache.clipKey(contentHash: 'abc', width: 720, height: 404),
        isNot(cache.clipKey(contentHash: 'def', width: 720, height: 404)),
      );
    });

    // The landmine: a preview decodes at a 720 proxy bound and a render at the
    // source's full resolution. Keying on content alone would serve the
    // preview's 720x404 raster to the render.
    test('a different decode width keys apart', () {
      final cache = cacheAt();
      expect(
        cache.clipKey(contentHash: 'abc', width: 720, height: 404),
        isNot(cache.clipKey(contentHash: 'abc', width: 1920, height: 404)),
      );
    });

    test('a different decode height keys apart', () {
      final cache = cacheAt();
      expect(
        cache.clipKey(contentHash: 'abc', width: 720, height: 404),
        isNot(cache.clipKey(contentHash: 'abc', width: 720, height: 1080)),
      );
    });

    // VP9 alpha survives libvpx-vp9 only; the native decoder drops it and the
    // same source composites over black. Different pixels, different key.
    test('a different decoder keys apart', () {
      final cache = cacheAt();
      expect(
        cache.clipKey(contentHash: 'abc', width: 720, height: 404, decoder: 'libvpx-vp9'),
        isNot(cache.clipKey(contentHash: 'abc', width: 720, height: 404)),
      );
    });
  });

  group('get/put', () {
    test('a miss returns null', () async {
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);
      expect(await cache.get(key, 0, byteLength: 16), isNull);
    });

    test('put then get round-trips the bytes', () async {
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);

      await cache.put(key, 3, rgba(4, 7));

      expect(await cache.get(key, 3, byteLength: 16), rgba(4, 7));
    });

    test('frames are addressed independently within a clip', () async {
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);

      await cache.put(key, 0, rgba(4, 1));
      await cache.put(key, 1, rgba(4, 2));

      expect(await cache.get(key, 0, byteLength: 16), rgba(4, 1));
      expect(await cache.get(key, 1, byteLength: 16), rgba(4, 2));
    });

    // A run killed mid-write leaves a short file. Serving it would hand the
    // decoder a raster of the wrong length forever; the entry must simply miss
    // and re-extract over itself.
    test('a truncated entry is a miss, not a short raster', () async {
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);
      await cache.put(key, 0, rgba(4, 7));
      File('${root.path}/clip_frames/$key/0.rgba').writeAsBytesSync(Uint8List(8));

      expect(await cache.get(key, 0, byteLength: 16), isNull);
    });

    test('a truncated entry heals: the next put is served again', () async {
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);
      File('${root.path}/clip_frames/$key/0.rgba')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(Uint8List(8));

      await cache.put(key, 0, rgba(4, 7));

      expect(await cache.get(key, 0, byteLength: 16), rgba(4, 7));
    });

    test('an unreadable entry is a miss', () async {
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);
      Directory('${root.path}/clip_frames/$key/0.rgba').createSync(recursive: true);

      expect(await cache.get(key, 0, byteLength: 16), isNull);
    });

    test('an unwritable root is not fatal: the run just stays cold', () async {
      File('${root.path}/clip_frames').writeAsBytesSync(Uint8List(0));
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);

      await expectLater(cache.put(key, 0, rgba(4, 7)), completes);
      expect(await cache.get(key, 0, byteLength: 16), isNull);
    });

    test('a malformed key is rejected rather than interpolated into a path', () {
      final cache = cacheAt();
      expect(() => cache.get('../escape', 0, byteLength: 16), throwsArgumentError);
      expect(() => cache.put('../escape', 0, rgba(4, 1)), throwsArgumentError);
      expect(() => cache.markUsed('../escape'), throwsArgumentError);
    });
  });

  group('sweep', () {
    test('a cache under the bound keeps every clip', () async {
      final cache = cacheAt(maxBytes: 1024);
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);
      await cache.put(key, 0, rgba(4, 1));

      await cache.sweep();

      expect(await cache.get(key, 0, byteLength: 16), isNotNull);
    });

    test('sweeping a cache that was never written is a no-op', () async {
      await expectLater(cacheAt().sweep(), completes);
    });

    // Whole clip keys are evicted, not individual frames: a half-evicted clip
    // re-extracts anyway.
    test('an over-budget cache evicts whole clip keys, least-recent first', () async {
      final cache = cacheAt(maxBytes: 200);
      final old = cache.clipKey(contentHash: 'old', width: 2, height: 2);
      final fresh = cache.clipKey(contentHash: 'fresh', width: 2, height: 2);
      for (var frame = 0; frame < 8; frame++) {
        await cache.put(old, frame, rgba(4, frame));
      }
      _ageTo(
        Directory('${root.path}/clip_frames/$old'),
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      for (var frame = 0; frame < 8; frame++) {
        await cache.put(fresh, frame, rgba(4, frame));
      }

      await cache.sweep();

      expect(
        Directory('${root.path}/clip_frames/$old').existsSync(),
        isFalse,
        reason: 'the least-recently-used clip key goes first',
      );
      expect(Directory('${root.path}/clip_frames/$fresh').existsSync(), isTrue);
    });

    test('eviction brings the cache back under the bound', () async {
      final cache = cacheAt(maxBytes: 200);
      for (var clip = 0; clip < 4; clip++) {
        final key = cache.clipKey(contentHash: 'clip$clip', width: 2, height: 2);
        for (var frame = 0; frame < 4; frame++) {
          await cache.put(key, frame, rgba(4, frame));
        }
        _ageTo(
          Directory('${root.path}/clip_frames/$key'),
          DateTime.now().subtract(Duration(hours: 4 - clip)),
        );
      }

      await cache.sweep();

      expect(_totalBytes(Directory('${root.path}/clip_frames')), lessThanOrEqualTo(200));
    });

    test('an unsweepable root is not fatal', () async {
      File('${root.path}/clip_frames').writeAsBytesSync(Uint8List(0));
      await expectLater(cacheAt(maxBytes: 0).sweep(), completes);
    });
  });

  group('markUsed', () {
    // Recency is the newest mtime under the clip key, and a read moves no
    // mtime — so a clip that only ever hits would look coldest and evict first.
    test('a served clip survives eviction over a newer but unserved one', () async {
      final cache = cacheAt(maxBytes: 200);
      final served = cache.clipKey(contentHash: 'served', width: 2, height: 2);
      final unserved = cache.clipKey(contentHash: 'unserved', width: 2, height: 2);
      for (var frame = 0; frame < 8; frame++) {
        await cache.put(served, frame, rgba(4, frame));
      }
      _ageTo(
        Directory('${root.path}/clip_frames/$served'),
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      for (var frame = 0; frame < 8; frame++) {
        await cache.put(unserved, frame, rgba(4, frame));
      }
      _ageTo(
        Directory('${root.path}/clip_frames/$unserved'),
        DateTime.now().subtract(const Duration(hours: 1)),
      );

      await cache.markUsed(served);
      await cache.sweep();

      expect(Directory('${root.path}/clip_frames/$served').existsSync(), isTrue);
      expect(Directory('${root.path}/clip_frames/$unserved').existsSync(), isFalse);
    });

    test('the marker adds no bytes to the size bound', () async {
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'abc', width: 2, height: 2);
      await cache.put(key, 0, rgba(4, 1));

      await cache.markUsed(key);

      expect(_totalBytes(Directory('${root.path}/clip_frames')), 16);
    });

    test('marking a clip the cache never held is not fatal', () async {
      final cache = cacheAt();
      final key = cache.clipKey(contentHash: 'absent', width: 2, height: 2);

      await expectLater(cache.markUsed(key), completes);

      expect(Directory('${root.path}/clip_frames/$key').existsSync(), isFalse);
    });
  });

  group('userCache', () {
    test('resolves under XDG_CACHE_HOME on POSIX', () {
      final cache = ClipFrameCache.userCache(
        environment: {'XDG_CACHE_HOME': '/xdg', 'HOME': '/home/dev'},
        windows: false,
      );
      expect(cache!.root.path, '/xdg/fluvie/clip_frames');
    });

    test('falls back to ~/.cache when XDG_CACHE_HOME is unset', () {
      final cache = ClipFrameCache.userCache(
        environment: {'HOME': '/home/dev'},
        windows: false,
      );
      expect(cache!.root.path, '/home/dev/.cache/fluvie/clip_frames');
    });

    test('an empty XDG_CACHE_HOME falls back to HOME', () {
      final cache = ClipFrameCache.userCache(
        environment: {'XDG_CACHE_HOME': '', 'HOME': '/home/dev'},
        windows: false,
      );
      expect(cache!.root.path, '/home/dev/.cache/fluvie/clip_frames');
    });

    test('resolves under LOCALAPPDATA on Windows', () {
      final cache = ClipFrameCache.userCache(
        environment: {'LOCALAPPDATA': r'C:\Users\dev\AppData\Local'},
        windows: true,
      );
      expect(cache!.root.path, r'C:\Users\dev\AppData\Local/fluvie/clip_frames');
    });

    // Never fall back to the system temp directory: filling it is the bug this
    // cache exists to stop, so an unresolvable base means "run uncached".
    test('no HOME on POSIX resolves to no cache at all', () {
      expect(ClipFrameCache.userCache(environment: const {}, windows: false), isNull);
    });

    test('no LOCALAPPDATA on Windows resolves to no cache at all', () {
      expect(ClipFrameCache.userCache(environment: const {}, windows: true), isNull);
    });

    test('an empty LOCALAPPDATA resolves to no cache at all', () {
      expect(
        ClipFrameCache.userCache(environment: const {'LOCALAPPDATA': ''}, windows: true),
        isNull,
      );
    });

    test('carries the size bound through', () {
      final cache = ClipFrameCache.userCache(
        environment: {'HOME': '/home/dev'},
        windows: false,
        maxBytes: 42,
      );
      expect(cache!.maxBytes, 42);
    });

    test('the default bound is 2 GiB', () {
      expect(ClipFrameCache.defaultMaxBytes, 2 * 1024 * 1024 * 1024);
    });
  });
}

/// Backdates every file under [dir] so eviction sees it as least-recently-used.
void _ageTo(Directory dir, DateTime when) {
  for (final entity in dir.listSync()) {
    if (entity is File) entity.setLastModifiedSync(when);
  }
}

int _totalBytes(Directory dir) {
  var total = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) total += entity.lengthSync();
  }
  return total;
}
