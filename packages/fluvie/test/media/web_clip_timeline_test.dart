import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/web_image_media_resolver.dart';

void main() {
  test('browser resolver exposes the decoder display timeline to shared clip planning', () async {
    final resolver = WebImageMediaResolver(
      loader: MediaBytesLoader(
        httpClient: _UnusedHttp(),
        allowlist: NetworkAllowlist.allowAny(),
        readFile: (_) async => Uint8List.fromList([1, 2]),
      ),
      clipDecoder: _Decoder(),
    );
    addTearDown(resolver.dispose);
    const source = MediaSource.file('cat.mp4');
    await resolver.preResolveAll([source]);
    await resolver.probeClip(source);
    expect(clipTimelineFor(resolver, source)?.frameAt(.35), 1);
    expect(clipTimelineFor(resolver, source)?.frameAt(.8), 2);
  });
}

final class _Decoder implements WebClipDecoder, WebClipTimelineDecoder {
  @override
  Future<ClipMetadata> probe(Uint8List bytes) async =>
      (fps: 3.0, frameCount: 3, width: 2, height: 2, hasAudio: false);

  @override
  Future<MediaTimeline?> probeTimeline(Uint8List bytes) async =>
      MediaTimeline.fromTimestamps([0, 100000, 600000], endTimeUs: 1000000);

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uint8List bytes,
    List<int> sourceFrames, {
    required int width,
    required int height,
  }) async => {};
}

final class _UnusedHttp implements MediaHttpClient {
  @override
  Future<Uint8List> get(Uri url) async => throw StateError('This fixture has no network sources.');
}
