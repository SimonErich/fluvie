// The MediaRepository clip path over a persistent ClipFrameCache: a run that
// re-resolves an unchanged clip must serve it from disk and never reach the
// extractor (ffmpeg spawns a process per frame, which is the placeholder wait
// a live preview shows on every hot restart). The extractor here counts its
// calls, so "did not extract" is asserted directly rather than timed.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/runtime/clip_frame_cache.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/encoding/frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this._data);
  final Map<String, Uint8List> _data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = _data[key];
    if (bytes == null) throw FluvieRenderException('asset not found: $key');
    return ByteData.view(bytes.buffer);
  }
}

class _NoHttp implements MediaHttpClient {
  @override
  Future<Uint8List> get(Uri url) async => throw FluvieRenderException('no network: $url');
}

class _FakeProbe implements VideoProbeService {
  _FakeProbe(this.result);
  final VideoProbeResult result;
  @override
  Future<VideoProbeResult> probe(String filePath) async => result;
}

/// An extractor that paints each frame a per-index shade and records every
/// frame it was asked for, at the size it was asked for.
class _CountingExtractor implements FrameExtractionService {
  final extracted = <int>[];
  final sizes = <String>{};

  @override
  Future<RawFrame> extractFrame(
    Uri source,
    int frameIndex, {
    required int width,
    required int height,
    String? decoder,
  }) async {
    extracted.add(frameIndex);
    sizes.add('${width}x$height');
    return RawFrame(
      frameIndex: frameIndex,
      width: width,
      height: height,
      rgba: Uint8List(width * height * 4)..fillRange(0, width * height * 4, frameIndex % 256),
    );
  }

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uri source,
    Iterable<int> frameIndices, {
    required int width,
    required int height,
    String? decoder,
  }) async => {
    for (final index in frameIndices)
      index: await extractFrame(source, index, width: width, height: height, decoder: decoder),
  };
}

const _clip = MediaSource.asset('clip_1s.webm');
final _clipBytes = Uint8List.fromList(List.generate(64, (i) => i));

const _h264 = VideoProbeResult(
  codec: 'h264',
  width: 8,
  height: 4,
  nbFrames: 30,
  durationSeconds: 1,
);
const _vp9 = VideoProbeResult(
  codec: 'vp9',
  width: 8,
  height: 4,
  nbFrames: 30,
  durationSeconds: 1,
);
const _vp9Alpha = VideoProbeResult(
  codec: 'vp9',
  width: 8,
  height: 4,
  nbFrames: 30,
  durationSeconds: 1,
  hasAlpha: true,
);

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fluvie_clip_cache_repo_test_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });

  ClipFrameCache cacheAt() => ClipFrameCache(Directory('${root.path}/clip_frames'));

  MediaRepository repo({
    required _CountingExtractor extractor,
    ClipFrameCache? cache,
    VideoProbeResult probed = _h264,
    int? maxClipDecodeEdge,
  }) => MediaRepository(
    loader: MediaBytesLoader(
      bundle: _MapBundle({'clip_1s.webm': _clipBytes}),
      httpClient: _NoHttp(),
      allowlist: NetworkAllowlist.allowAny(),
    ),
    probeService: _FakeProbe(probed),
    frameExtractor: extractor,
    clipFrameCache: cache,
    maxClipDecodeEdge: maxClipDecodeEdge,
  );

  /// One full run: the image pre-pass content-hashes the clip source (that hash
  /// is the cache key), then the clip pre-pass resolves [frames].
  Future<MediaRepository> run(
    _CountingExtractor extractor, {
    ClipFrameCache? cache,
    VideoProbeResult probed = _h264,
    int? maxClipDecodeEdge,
    List<int> frames = const [0, 1, 2],
  }) async {
    final repository = repo(
      extractor: extractor,
      cache: cache,
      probed: probed,
      maxClipDecodeEdge: maxClipDecodeEdge,
    );
    addTearDown(repository.dispose);
    await repository.preResolveAll([_clip]);
    await repository.preResolveClip(_clip, frames);
    return repository;
  }

  test('a cold run extracts every frame and stores it', () async {
    final extractor = _CountingExtractor();

    await run(extractor, cache: cacheAt());

    expect(extractor.extracted, [0, 1, 2]);
    expect(
      Directory('${root.path}/clip_frames').listSync().whereType<Directory>(),
      hasLength(1),
      reason: 'the run stored one clip key',
    );
  });

  // Problem A: this is the placeholder wait. A second run over an unchanged
  // clip must not spawn ffmpeg once.
  test('a warm run serves every frame from disk without extracting', () async {
    final cache = cacheAt();
    await run(_CountingExtractor(), cache: cache);

    final second = _CountingExtractor();
    await run(second, cache: cache);

    expect(second.extracted, isEmpty, reason: 'the extractor must not be called at all');
  });

  test('a warm run serves the same pixels the cold run extracted', () async {
    final cache = cacheAt();
    final first = await run(_CountingExtractor(), cache: cache);
    final cold = await first.decodedClipFrame(_clip, 1).toByteData();

    final second = await run(_CountingExtractor(), cache: cache);
    final warm = await second.decodedClipFrame(_clip, 1).toByteData();

    expect(warm!.buffer.asUint8List(), cold!.buffer.asUint8List());
  });

  test('a partially cached run extracts only the frames it is missing', () async {
    final cache = cacheAt();
    await run(_CountingExtractor(), cache: cache, frames: [0, 1]);

    final second = _CountingExtractor();
    await run(second, cache: cache, frames: [0, 1, 2, 3]);

    expect(second.extracted, [2, 3]);
  });

  test('a different clip is a miss, not another clip’s frames', () async {
    final cache = cacheAt();
    await run(_CountingExtractor(), cache: cache);

    final other = _CountingExtractor();
    final repository = MediaRepository(
      loader: MediaBytesLoader(
        bundle: _MapBundle({'clip_1s.webm': Uint8List.fromList(List.filled(64, 9))}),
        httpClient: _NoHttp(),
        allowlist: NetworkAllowlist.allowAny(),
      ),
      probeService: _FakeProbe(_h264),
      frameExtractor: other,
      clipFrameCache: cache,
    );
    addTearDown(repository.dispose);
    await repository.preResolveAll([_clip]);
    await repository.preResolveClip(_clip, [0, 1, 2]);

    expect(other.extracted, [0, 1, 2], reason: 'different bytes, different key');
  });

  // THE LANDMINE. A preview decodes at a proxy bound and a render at full
  // source resolution. If the key ignored the decode size, the render would
  // silently paint the preview's smaller raster.
  group('the decode is part of the key', () {
    test('a smaller decode bound is a miss against a full-resolution entry', () async {
      final cache = cacheAt();
      await run(_CountingExtractor(), cache: cache);

      final preview = _CountingExtractor();
      await run(preview, cache: cache, maxClipDecodeEdge: 4);

      expect(preview.extracted, [0, 1, 2], reason: 'a 4x2 proxy is not an 8x4 raster');
      expect(preview.sizes, {'4x2'});
    });

    test('a full-resolution run is a miss against a proxy entry', () async {
      final cache = cacheAt();
      await run(_CountingExtractor(), cache: cache, maxClipDecodeEdge: 4);

      final render = _CountingExtractor();
      await run(render, cache: cache);

      expect(render.extracted, [0, 1, 2], reason: 'a render must never get the proxy raster');
      expect(render.sizes, {'8x4'});
    });

    test('a render after a preview paints at the full source size', () async {
      final cache = cacheAt();
      await run(_CountingExtractor(), cache: cache, maxClipDecodeEdge: 4);

      final render = await run(_CountingExtractor(), cache: cache);

      expect(render.decodedClipFrame(_clip, 0).width, 8);
      expect(render.decodedClipFrame(_clip, 0).height, 4);
    });

    test('the same bound twice is a hit', () async {
      final cache = cacheAt();
      await run(_CountingExtractor(), cache: cache, maxClipDecodeEdge: 4);

      final second = _CountingExtractor();
      await run(second, cache: cache, maxClipDecodeEdge: 4);

      expect(second.extracted, isEmpty);
    });

    // VP9 codes alpha as a layer only libvpx-vp9 reads; the native decoder
    // drops it and the clip composites over black. Same codec and size, and
    // only the decoder between them, so only the decoder can key them apart.
    test('a different decoder is a miss against the same source and size', () async {
      final cache = cacheAt();
      await run(_CountingExtractor(), cache: cache, probed: _vp9);

      final alpha = _CountingExtractor();
      await run(alpha, cache: cache, probed: _vp9Alpha);

      expect(alpha.extracted, [0, 1, 2], reason: 'libvpx-vp9 decodes different pixels');
    });
  });

  group('the cache is optional', () {
    test('no cache keeps the extract-every-run behaviour', () async {
      final extractor = _CountingExtractor();
      await run(extractor, frames: [0]);
      await run(extractor, frames: [0]);

      expect(extractor.extracted, [0, 0]);
    });

    test('a clip never content-hashed runs uncached rather than keying on its path', () async {
      final cache = cacheAt();
      final extractor = _CountingExtractor();
      final repository = repo(extractor: extractor, cache: cache);
      addTearDown(repository.dispose);

      await repository.preResolveClip(_clip, [0]);

      expect(extractor.extracted, [0]);
      expect(
        Directory('${root.path}/clip_frames').existsSync(),
        isFalse,
        reason: 'the materialized path is a fresh temp dir every run, so it is no key',
      );
    });
  });

  tearDownAll(() {
    for (final entry in Directory.systemTemp.listSync()) {
      if (entry is Directory && entry.path.contains('fluvie_clip_src_')) {
        entry.deleteSync(recursive: true);
      }
    }
  });
}
