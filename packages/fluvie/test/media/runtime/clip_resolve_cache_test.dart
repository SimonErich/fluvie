// Task 21: the shared ClipResolveCache mixin. It owns the platform-agnostic clip
// path (cache the probed metadata, diff and extract only the missing frames,
// decode each RawFrame to a ui.Image, serve them synchronously behind the
// pre-resolve guard) and defers the how of probing and extracting to its two
// abstract methods. A fake harness drives it without ffmpeg or WebCodecs.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/runtime/clip_resolve_cache.dart';
import 'package:fluvie/src/media/runtime/image_resolve_cache.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// An in-memory [ClipFrameStore] for the streaming-mode tests (the real
/// on-device store writes files; this keeps the raw bytes in a map).
final class _MemoryClipFrameStore implements ClipFrameStore {
  final Map<String, Uint8List> _frames = {};
  bool disposed = false;

  @override
  Future<void> put(String clipKey, int frame, Uint8List rgba) async =>
      _frames['$clipKey#$frame'] = rgba;

  @override
  Future<Uint8List?> get(String clipKey, int frame) async => _frames['$clipKey#$frame'];

  @override
  Future<void> dispose() async {
    disposed = true;
    _frames.clear();
  }
}

/// A minimal resolver that mixes in the cache under test and serves canned
/// metadata and 2x2 frames, counting probe and extract calls. Pass a `store`
/// (and optional `windowCapacity`) to exercise the streaming decode-ahead path.
final class _FakeClipCache with ImageResolveCache, ClipResolveCache {
  _FakeClipCache(this._meta, {ClipFrameStore? store, int windowCapacity = 16})
    : clipFrameStore = store,
      clipWindowCapacity = windowCapacity;

  final ClipMetadata _meta;
  int probeCalls = 0;
  final extracted = <int>[];

  @override
  final ClipFrameStore? clipFrameStore;

  @override
  final int clipWindowCapacity;

  // The clip path never touches the byte loader, so the image-cache seam can
  // stay unimplemented in this harness.
  @override
  MediaBytesLoader get loader => throw UnimplementedError();

  @override
  Future<ClipMetadata> probeClipSource(MediaSource source) async {
    probeCalls++;
    return _meta;
  }

  @override
  Future<Map<int, RawFrame>> extractClipFrames(
    MediaSource source,
    List<int> sourceFrames,
    ClipMetadata meta,
  ) async {
    extracted.addAll(sourceFrames);
    return {
      for (final i in sourceFrames)
        i: RawFrame(
          frameIndex: i,
          width: meta.width,
          height: meta.height,
          rgba: Uint8List(meta.width * meta.height * 4)
            ..fillRange(0, meta.width * meta.height * 4, i % 256),
        ),
    };
  }
}

const _clip = MediaSource.asset('clip.mp4');
const ClipMetadata _meta = (fps: 30.0, frameCount: 30, width: 2, height: 2);

void main() {
  test('resolveClipMeta probes once and caches', () async {
    final cache = _FakeClipCache(_meta);

    final first = await cache.resolveClipMeta(_clip);
    final second = await cache.resolveClipMeta(_clip);

    expect(first, _meta);
    expect(second, first);
    expect(cache.probeCalls, 1, reason: 'metadata is cached after the first probe');
  });

  test('resolveClipFrames extracts the listed frames once, deduping', () async {
    final cache = _FakeClipCache(_meta);

    await cache.resolveClipFrames(_clip, [0, 5]);
    await cache.resolveClipFrames(_clip, [5, 10]);

    expect(cache.extracted, [0, 5, 10], reason: 'frame 5 must not re-extract');
    expect(cache.probeCalls, 1, reason: 'probe is shared across resolve calls');
  });

  test('decodedClipFrameLookup serves a sync image after markResolved', () async {
    final cache = _FakeClipCache(_meta)..markResolved();

    await cache.resolveClipFrames(_clip, [0]);

    expect(cache.decodedClipFrameLookup(_clip, 0).width, 2);
    expect(cache.clipMetadataLookup(_clip).frameCount, 30);
  });

  test('lookups before markResolved throw StateError', () {
    final cache = _FakeClipCache(_meta);

    expect(() => cache.clipMetadataLookup(_clip), throwsA(isA<StateError>()));
    expect(() => cache.decodedClipFrameLookup(_clip, 0), throwsA(isA<StateError>()));
  });

  test('decodedClipFrameLookup of an un-extracted frame throws a typed error', () async {
    final cache = _FakeClipCache(_meta)..markResolved();
    await cache.resolveClipFrames(_clip, [0]);

    expect(
      () => cache.decodedClipFrameLookup(_clip, 99),
      throwsA(isA<FluvieRenderException>().having((e) => e.message, 'message', contains('99'))),
    );
  });

  test('disposeClipFrames releases every frame and is idempotent', () async {
    final cache = _FakeClipCache(_meta)..markResolved();
    await cache.resolveClipFrames(_clip, [0]);
    final frame = cache.decodedClipFrameLookup(_clip, 0);

    cache.disposeClipFrames();

    expect(frame.debugDisposed, isTrue);
    expect(cache.disposeClipFrames, returnsNormally, reason: 'a second dispose is a no-op');
  });

  group('streaming mode (a clip-frame store)', () {
    test('extracts frames into the store, not the decode-all cache', () async {
      final store = _MemoryClipFrameStore();
      final cache = _FakeClipCache(_meta, store: store)..markResolved();

      await cache.resolveClipFrames(_clip, [0, 1, 2]);

      expect(
        cache.clipFrames[_clip] ?? const {},
        isEmpty,
        reason: 'streaming mode never fills the in-memory decode-all cache',
      );
      expect(await store.get('clip0', 0), isNotNull);
      expect(await store.get('clip0', 2), isNotNull);
    });

    test('prepareClipFrames decodes the resampled frame for paint to read', () async {
      final store = _MemoryClipFrameStore();
      final cache = _FakeClipCache(_meta, store: store)
        ..markResolved()
        ..registerClipPlan(
          source: _clip,
          windowStart: 0,
          windowLength: 30,
          compFps: 30,
          trimStartFrames: 0,
          trimEndFrames: 30,
        );
      await cache.resolveClipFrames(_clip, [0, 10, 15, 20]);

      // Composition frame 15 at 30fps over a 30fps source maps to source 15.
      await cache.prepareClipFramesForComposition(15);

      expect(cache.decodedClipFrameLookup(_clip, 15).width, 2);
    });

    test('an off-window composition frame warms the clamped boundary frame', () async {
      // Regression: a clip in a later scene still paints (clamped to its first
      // source frame) while an earlier scene is on screen, so prepare must warm
      // that clamped frame for composition frames before the clip's window —
      // not skip them.
      final store = _MemoryClipFrameStore();
      final cache = _FakeClipCache(_meta, store: store)
        ..markResolved()
        ..registerClipPlan(
          source: _clip,
          windowStart: 30,
          windowLength: 30,
          compFps: 30,
          trimStartFrames: 0,
          trimEndFrames: 30,
        );
      await cache.resolveClipFrames(_clip, [0]);

      // Composition frame 0 is before the window (windowStart 30): the resampler
      // clamps it to the trim start (source 0), which paint then reads.
      await cache.prepareClipFramesForComposition(0);

      expect(cache.decodedClipFrameLookup(_clip, 0).width, 2);
    });

    test('the decode window evicts least-recently-used beyond capacity', () async {
      final store = _MemoryClipFrameStore();
      final cache = _FakeClipCache(_meta, store: store, windowCapacity: 2)
        ..markResolved()
        ..registerClipPlan(
          source: _clip,
          windowStart: 0,
          windowLength: 30,
          compFps: 30,
          trimStartFrames: 0,
          trimEndFrames: 30,
        );
      await cache.resolveClipFrames(_clip, [0, 1, 2]);

      // comp frame f maps 1:1 to source f here; three frames, capacity two.
      for (final f in [0, 1, 2]) {
        await cache.prepareClipFramesForComposition(f);
      }

      expect(
        () => cache.decodedClipFrameLookup(_clip, 0),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('decode window'),
          ),
        ),
        reason: 'the oldest frame was evicted',
      );
      expect(cache.decodedClipFrameLookup(_clip, 2).width, 2);
    });
  });
}
