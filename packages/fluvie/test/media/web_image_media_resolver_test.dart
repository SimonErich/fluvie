import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/disposable_resolver.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';
import 'package:fluvie/src/media/web_image_media_resolver.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// Encodes a 2x2 solid PNG so the resolver has real image bytes to decode.
Future<Uint8List> _pngBytes([int color = 0xFF3366CC]) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 2, 2),
    ui.Paint()..color = ui.Color(color),
  );
  final image = await recorder.endRecording().toImage(2, 2);
  addTearDown(image.dispose);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this._data);
  final Map<String, Uint8List> _data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = _data[key];
    if (bytes == null) {
      throw FluvieRenderException('asset not found: $key');
    }
    return ByteData.view(bytes.buffer);
  }
}

class _MapHttpClient implements MediaHttpClient {
  _MapHttpClient(this._data);
  final Map<Uri, Uint8List> _data;
  @override
  Future<Uint8List> get(Uri url) async {
    final bytes = _data[url];
    if (bytes == null) {
      throw FluvieRenderException('no canned bytes for "$url"');
    }
    return bytes;
  }
}

class _UnusedSnapshotService implements SnapshotService {
  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async =>
      SnapshotRaster(bytes: Uint8List(0), contentHash: 'x', width: 1, height: 1);
}

class _UnusedBeats implements BeatDetectionService {
  @override
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames}) =>
      throw UnimplementedError();
}

class _UnusedAnalyzer implements FrequencyAnalyzer {
  @override
  Future<BandTable> analyze(AudioSource source, {required int fps, required int totalFrames}) =>
      throw UnimplementedError();
}

WebImageMediaResolver _resolver({
  Map<String, Uint8List> assets = const {},
  Map<Uri, Uint8List> network = const {},
  Future<Uint8List> Function(String path)? readFile,
  WebClipDecoder? clipDecoder,
}) => WebImageMediaResolver(
  loader: MediaBytesLoader(
    bundle: _MapBundle(assets),
    httpClient: _MapHttpClient(network),
    allowlist: NetworkAllowlist.allowAny(),
    readFile: readFile,
  ),
  clipDecoder: clipDecoder,
);

/// A clip decoder that ignores the bytes and serves canned metadata plus solid
/// 2x2 frames, counting probe and extract calls.
class _FakeClipDecoder implements WebClipDecoder {
  _FakeClipDecoder(this._meta);
  final ClipMetadata _meta;
  int probeCalls = 0;
  final extracted = <int>[];

  @override
  Future<ClipMetadata> probe(Uint8List bytes) async {
    probeCalls++;
    return _meta;
  }

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uint8List bytes,
    List<int> sourceFrames, {
    required int width,
    required int height,
  }) async {
    extracted.addAll(sourceFrames);
    return {
      for (final i in sourceFrames)
        i: RawFrame(
          frameIndex: i,
          width: width,
          height: height,
          rgba: Uint8List(width * height * 4)..fillRange(0, width * height * 4, i % 256),
        ),
    };
  }
}

const ClipMetadata _clipMeta = (fps: 30.0, frameCount: 30, width: 2, height: 2, hasAudio: false);

Future<Uint8List> _rgbaOf(ui.Image image) async {
  final data = await image.toByteData();
  return data!.buffer.asUint8List();
}

void main() {
  group('WebImageMediaResolver image path', () {
    test('resolves an asset to bytes and an FNV content hash, then decodes it', () async {
      final png = await _pngBytes();
      final resolver = _resolver(assets: {'a.png': png});
      const source = MediaSource.asset('a.png');

      await resolver.preResolveAll([source]);

      expect(resolver.resolvedFor(source).bytes, png);
      expect(resolver.resolvedFor(source).contentHash, isNotEmpty);
      final image = resolver.decodedImageFor(source);
      expect(image.width, 2);
      expect(image.height, 2);
    });

    test('resolves a network source through the http client', () async {
      final png = await _pngBytes();
      final url = Uri.parse('https://example.com/a.png');
      final resolver = _resolver(network: {url: png});
      final source = MediaSource.network(url);

      await resolver.preResolveAll([source]);

      expect(resolver.decodedImageFor(source).width, 2);
    });

    test('resolves a memory source verbatim', () async {
      final png = await _pngBytes();
      final resolver = _resolver();
      final source = MediaSource.memory(png);

      await resolver.preResolveAll([source]);

      expect(resolver.resolvedFor(source).bytes, same(png));
      expect(resolver.decodedImageFor(source).height, 2);
    });

    test('the same source twice loads once (idempotent cache)', () async {
      final png = await _pngBytes();
      final resolver = _resolver(assets: {'a.png': png});
      const source = MediaSource.asset('a.png');

      await resolver.preResolveAll([source, source]);
      await resolver.preResolveAll([source]);

      expect(resolver.decodedImageFor(source).width, 2);
    });

    test('decodes an asset image to its full rgba raster', () async {
      final png = await _pngBytes();
      const source = MediaSource.asset('a.png');

      final resolver = _resolver(assets: {'a.png': png});
      await resolver.preResolveAll([source]);

      expect((await _rgbaOf(resolver.decodedImageFor(source))).length, 2 * 2 * 4);
    });

    test('dispose releases decoded images and is idempotent', () async {
      final png = await _pngBytes();
      final resolver = _resolver(assets: {'a.png': png});
      const source = MediaSource.asset('a.png');
      await resolver.preResolveAll([source]);
      final image = resolver.decodedImageFor(source);

      expect(resolver, isA<DisposableResolver>());
      resolver.dispose();

      expect(image.debugDisposed, isTrue);
      expect(resolver.dispose, returnsNormally, reason: 'a second dispose is a no-op');
    });

    test('resolvedFor before preResolveAll throws StateError', () {
      final resolver = _resolver();
      expect(() => resolver.resolvedFor(const MediaSource.asset('a.png')), throwsStateError);
    });

    test('decodedImageFor before preResolveAll throws StateError', () {
      final resolver = _resolver();
      expect(() => resolver.decodedImageFor(const MediaSource.asset('a.png')), throwsStateError);
    });

    test('an unknown source after pre-resolve throws a typed error naming it', () async {
      final png = await _pngBytes();
      final resolver = _resolver(assets: {'a.png': png});
      await resolver.preResolveAll([const MediaSource.asset('a.png')]);

      expect(
        () => resolver.resolvedFor(const MediaSource.asset('b.png')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('b.png')),
        ),
      );
      expect(
        () => resolver.decodedImageFor(const MediaSource.asset('b.png')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('b.png')),
        ),
      );
    });
  });

  group('WebImageMediaResolver clip path', () {
    const clip = MediaSource.asset('v.mp4');
    Map<String, Uint8List> clipAssets() => {
      'v.mp4': Uint8List.fromList(const [0, 1, 2]),
    };

    test('preResolveAll content-hashes a clip without decoding it as an image', () async {
      final resolver = _resolver(assets: clipAssets(), clipDecoder: _FakeClipDecoder(_clipMeta));

      await resolver.preResolveAll([clip]);

      expect(resolver.resolvedFor(clip).contentHash, isNotEmpty);
    });

    test('resolves a clip through the injected decoder', () async {
      final decoder = _FakeClipDecoder(_clipMeta);
      final resolver = _resolver(assets: clipAssets(), clipDecoder: decoder);

      await resolver.preResolveAll([clip]);
      await resolver.preResolveClip(clip, [0, 5]);

      expect(decoder.probeCalls, 1);
      expect(decoder.extracted, [0, 5]);
      expect(resolver.clipMetadataFor(clip).frameCount, 30);
      expect(resolver.decodedClipFrame(clip, 0).width, 2);
      expect(resolver.decodedClipFrame(clip, 5).height, 2);
    });

    test('probeClip without a decoder fails with a clear typed error', () async {
      final resolver = _resolver(assets: clipAssets());

      await expectLater(
        () => resolver.probeClip(clip),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('v.mp4'))
              .having((e) => e.message, 'message', contains('WebClipDecoder')),
        ),
      );
    });

    test('preResolveClip without a decoder fails with a clear typed error', () async {
      final resolver = _resolver(assets: clipAssets());

      await expectLater(
        () => resolver.preResolveClip(clip, [0]),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('v.mp4')),
        ),
      );
    });

    test('clip lookups before preResolveClip throw StateError', () {
      final resolver = _resolver(clipDecoder: _FakeClipDecoder(_clipMeta));

      expect(() => resolver.clipMetadataFor(clip), throwsStateError);
      expect(() => resolver.decodedClipFrame(clip, 0), throwsStateError);
    });

    test('dispose releases extracted clip frames', () async {
      final resolver = _resolver(assets: clipAssets(), clipDecoder: _FakeClipDecoder(_clipMeta));
      await resolver.preResolveAll([clip]);
      await resolver.preResolveClip(clip, [0]);
      final frame = resolver.decodedClipFrame(clip, 0);

      resolver.dispose();

      expect(frame.debugDisposed, isTrue);
    });
  });

  group('WebImageMediaResolver rejects what the browser cannot render', () {
    test('a file source surfaces the loader web seam error', () async {
      final resolver = _resolver(
        readFile: (path) async =>
            throw FluvieRenderException('file:// media sources are not supported on web ($path)'),
      );
      await expectLater(
        () => resolver.preResolveAll([const MediaSource.file('/local/photo.png')]),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('/local/photo.png'),
          ),
        ),
      );
    });

    test('empty collection pre-resolves are no-ops (a media-light web render)', () async {
      final resolver = _resolver();
      await expectLater(
        resolver.preResolveSnapshots(const [], _UnusedSnapshotService()),
        completes,
      );
      await expectLater(resolver.preResolveAudio(const []), completes);
      await expectLater(
        resolver.preResolveReactive(
          const [],
          beatDetector: _UnusedBeats(),
          analyzer: _UnusedAnalyzer(),
          fps: 30,
          totalFrames: 90,
        ),
        completes,
      );
    });

    test('clip, snapshot, audio, reactive, and caption members throw typed web errors', () {
      final resolver = _resolver();
      void expectsWeb(void Function() call, String needle) => expect(
        call,
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains(needle))
              .having((e) => e.message, 'message', contains('not supported on web')),
        ),
      );

      expectsWeb(
        () => resolver.preResolveSnapshots(
          const [SnapshotSource.mermaid('graph TD; A-->B')],
          _UnusedSnapshotService(),
        ),
        'mermaid',
      );
      expectsWeb(
        () => resolver.decodedSnapshotFor(const SnapshotSource.mermaid('graph TD; A-->B')),
        'mermaid',
      );
      expectsWeb(() => resolver.preResolveAudio(const [AudioSource.asset('s.mp3')]), 's.mp3');
      expectsWeb(
        () => resolver.materializedAudioPathFor(const AudioSource.asset('s.mp3')),
        's.mp3',
      );
      expectsWeb(
        () => resolver.preResolveReactive(
          const [AudioSource.asset('b.mp3')],
          beatDetector: _UnusedBeats(),
          analyzer: _UnusedAnalyzer(),
          fps: 30,
          totalFrames: 90,
        ),
        'b.mp3',
      );
      expectsWeb(() => resolver.beatGridFor(const AudioSource.asset('b.mp3')), 'b.mp3');
      expectsWeb(() => resolver.bandTableFor(const AudioSource.asset('b.mp3')), 'b.mp3');
      expectsWeb(() => resolver.preResolveCaptions(const CaptionSource.srt('s.srt')), 's.srt');
      expectsWeb(() => resolver.cuesFor(const CaptionSource.vtt('s.vtt')), 's.vtt');
    });
  });
}
