import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/runtime/clip_frame_cache.dart';

void main() {
  test(
    'changing decoder build invalidates the same source raster in a public repository',
    () async {
      final root = await Directory.systemTemp.createTemp('fluvie_decoder_identity_');
      addTearDown(() => root.delete(recursive: true));
      final cache = ClipFrameCache(root);
      final first = _IdentifiedExtractor('backend-a', 16);
      final second = _IdentifiedExtractor('backend-b', 32);
      await _pixels(first, cache);
      expect(await _pixels(second, cache), 32);
      expect(second.calls, 1);
    },
  );

  test('the same explicit backend identity can reuse persisted pixels', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_decoder_identity_');
    addTearDown(() => root.delete(recursive: true));
    final cache = ClipFrameCache(root);
    await _pixels(_IdentifiedExtractor('backend-a', 16), cache);
    final second = _IdentifiedExtractor('backend-a', 16);
    expect(await _pixels(second, cache), 16);
    expect(second.calls, 0);
  });

  for (final extractor in <_Extractor>[
    _Extractor(32),
    _IdentifiedExtractor(null, 32),
    _IdentifiedExtractor(' ', 32),
  ]) {
    test(
      'unidentified custom extraction stays correct with a populated cache (${extractor.runtimeType})',
      () async {
        final root = await Directory.systemTemp.createTemp('fluvie_decoder_identity_');
        addTearDown(() => root.delete(recursive: true));
        final cache = ClipFrameCache(root);
        await _pixels(_IdentifiedExtractor('backend-a', 16), cache);
        expect(await _pixels(extractor, cache), 32);
        expect(extractor.calls, 1);
      },
    );
  }

  test('backend identity is resolved once per repository across extraction batches', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_decoder_identity_');
    addTearDown(() => root.delete(recursive: true));
    final extractor = _IdentifiedExtractor('backend-a', 16);
    final repository = _repository(extractor, ClipFrameCache(root));
    addTearDown(repository.dispose);
    const clip = MediaSource.asset('cat.mp4');
    await repository.preResolveAll([clip]);
    await repository.preResolveClip(clip, [0]);
    await repository.preResolveClip(clip, [1]);
    expect(extractor.identityCalls, 1);
    expect(extractor.calls, 2);
  });
}

Future<int> _pixels(_Extractor extractor, ClipFrameCache cache) async {
  const clip = MediaSource.asset('cat.mp4');
  final repository = _repository(extractor, cache);
  addTearDown(repository.dispose);
  await repository.preResolveAll([clip]);
  await repository.preResolveClip(clip, [0]);
  final pixels = await repository.decodedClipFrame(clip, 0).toByteData();
  return pixels!.getUint8(0);
}

MediaRepository _repository(_Extractor extractor, ClipFrameCache cache) => MediaRepository(
  loader: MediaBytesLoader(
    bundle: _Bundle(),
    httpClient: _OfflineHttp(),
    allowlist: NetworkAllowlist.allowAny(),
  ),
  frameExtractor: extractor,
  probeService: _Probe(),
  clipFrameCache: cache,
);

class _Extractor implements FrameExtractionService {
  _Extractor(this.red);
  final int red;
  int calls = 0;
  @override
  Future<RawFrame> extractFrame(
    Uri source,
    int frameIndex, {
    required int width,
    required int height,
    String? decoder,
  }) async {
    calls++;
    return RawFrame(
      frameIndex: frameIndex,
      width: width,
      height: height,
      rgba: Uint8List.fromList([red, 0, 0, 255]),
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

class _IdentifiedExtractor extends _Extractor implements FrameExtractionCacheIdentity {
  _IdentifiedExtractor(this.identity, super.red);
  final String? identity;
  int identityCalls = 0;
  @override
  Future<String?> get cacheIdentity async {
    identityCalls++;
    return identity;
  }
}

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
}

class _OfflineHttp implements MediaHttpClient {
  @override
  Future<Uint8List> get(Uri url) async => throw StateError('Unexpected network: $url');
}

class _Probe implements VideoProbeService {
  @override
  Future<VideoProbeResult> probe(String filePath) async =>
      const VideoProbeResult(codec: 'h264', width: 1, height: 1, nbFrames: 2, durationSeconds: 1);
}
