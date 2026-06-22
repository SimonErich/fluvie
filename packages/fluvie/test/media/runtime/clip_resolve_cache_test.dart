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

/// A minimal resolver that mixes in the cache under test and serves canned
/// metadata and 2x2 frames, counting probe and extract calls.
final class _FakeClipCache with ImageResolveCache, ClipResolveCache {
  _FakeClipCache(this._meta);

  final ClipMetadata _meta;
  int probeCalls = 0;
  final extracted = <int>[];

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
}
