import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/contracts/disposable_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart';

/// A snapshot service that rasterizes every request to a fixed PNG, counting
/// its calls so cache-hit behaviour can be asserted.
class _CountingSnapshotService implements SnapshotService {
  _CountingSnapshotService(this._png);
  final Uint8List _png;
  int calls = 0;

  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async {
    calls++;
    return SnapshotRaster(
      bytes: _png,
      contentHash: fnv1a64Hex(_png),
      width: 2,
      height: 2,
    );
  }
}

/// A snapshot service that fails the test the instant it is called, so a
/// disallowed-host pre-resolve can prove the service is never reached.
class _NeverCalledSnapshotService implements SnapshotService {
  bool called = false;

  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async {
    called = true;
    fail('rasterize must not be reached for a disallowed host');
  }
}

/// Encodes a 2x2 solid PNG so the repository has real image bytes to decode.
Future<Uint8List> _pngBytes() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 2, 2),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
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

class _CountingHttpClient implements MediaHttpClient {
  _CountingHttpClient(this._data);
  final Map<Uri, Uint8List> _data;
  int calls = 0;
  @override
  Future<Uint8List> get(Uri url) async {
    calls++;
    final bytes = _data[url];
    if (bytes == null) {
      throw FluvieRenderException('no canned bytes for "$url"');
    }
    return bytes;
  }
}

MediaRepository _repo({
  Map<String, Uint8List> assets = const {},
  MediaHttpClient? client,
  Map<Uri, Uint8List> network = const {},
}) => MediaRepository(
  loader: MediaBytesLoader(
    bundle: _MapBundle(assets),
    httpClient: client ?? _CountingHttpClient(network),
    allowlist: NetworkAllowlist.allowAny(),
  ),
);

void main() {
  group('MediaRepository.preResolveAll + resolvedFor', () {
    test('resolves each source to bytes and an FNV content hash', () async {
      final png = await _pngBytes();
      final repo = _repo(assets: {'a.png': png});
      const source = MediaSource.asset('a.png');

      await repo.preResolveAll([source]);
      final resolved = repo.resolvedFor(source);

      expect(resolved.bytes, png);
      expect(resolved.contentHash, fnv1a64Hex(png));
    });

    test('resolvedFor before preResolveAll throws StateError', () {
      final repo = _repo();
      expect(
        () => repo.resolvedFor(const MediaSource.asset('a.png')),
        throwsA(isA<StateError>()),
      );
    });

    test('an unknown source after pre-resolve throws a typed error', () async {
      final png = await _pngBytes();
      final repo = _repo(assets: {'a.png': png});
      await repo.preResolveAll([const MediaSource.asset('a.png')]);

      expect(
        () => repo.resolvedFor(const MediaSource.asset('b.png')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('b.png')),
        ),
      );
    });

    test('a disallowed host surfaces a typed error from pre-resolve', () async {
      final repo = MediaRepository(
        loader: MediaBytesLoader(
          bundle: _MapBundle(const {}),
          httpClient: _CountingHttpClient(const {}),
          allowlist: const NetworkAllowlist(hosts: {'example.com'}),
        ),
      );
      final source = MediaSource.network(Uri.parse('https://evil.test/x.png'));

      await expectLater(
        () => repo.preResolveAll([source]),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('evil.test')),
        ),
      );
    });

    test('a missing file surfaces a typed error from pre-resolve', () async {
      final repo = _repo();
      await expectLater(
        () => repo.preResolveAll([const MediaSource.file('/no/such.png')]),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('/no/such.png'),
          ),
        ),
      );
    });
  });

  group('MediaRepository idempotency', () {
    test('the same source twice loads once; the second is a cache hit', () async {
      final png = await _pngBytes();
      final url = Uri.parse('https://example.com/a.png');
      final client = _CountingHttpClient({url: png});
      final repo = _repo(client: client);
      final source = MediaSource.network(url);

      await repo.preResolveAll([source, source]);
      await repo.preResolveAll([source]);

      expect(client.calls, 1, reason: 'cache must dedupe across and within calls');
    });
  });

  group('MediaRepository.decodedImageFor', () {
    test('returns a sync ui.Image for an image source after pre-resolve', () async {
      final png = await _pngBytes();
      final repo = _repo(assets: {'a.png': png});
      const source = MediaSource.asset('a.png');

      await repo.preResolveAll([source]);
      final image = repo.decodedImageFor(source);

      expect(image.width, 2);
      expect(image.height, 2);
    });

    test('decodedImageFor before preResolveAll throws StateError', () {
      final repo = _repo();
      expect(
        () => repo.decodedImageFor(const MediaSource.asset('a.png')),
        throwsA(isA<StateError>()),
      );
    });

    test('decodedImageFor of an unresolved source throws a typed error', () async {
      final png = await _pngBytes();
      final repo = _repo(assets: {'a.png': png});
      await repo.preResolveAll([const MediaSource.asset('a.png')]);

      expect(
        () => repo.decodedImageFor(const MediaSource.asset('b.png')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('b.png')),
        ),
      );
    });

    test('undecodable bytes surface a typed error from pre-resolve', () async {
      final repo = _repo(
        assets: {
          'broken.png': Uint8List.fromList([0, 1, 2, 3]),
        },
      );
      await expectLater(
        () => repo.preResolveAll([const MediaSource.asset('broken.png')]),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('broken.png')),
        ),
      );
    });

    test('a clip-extension source is not decoded as an image (self-protecting)', () async {
      // A footgun guard: passing an mp4 to preResolveAll must not attempt an
      // image decode (which would throw on video bytes). The clip path
      // (preResolveClip) owns clips; preResolveAll skips their image decode.
      final repo = _repo(
        assets: {
          'movie.mp4': Uint8List.fromList([0, 1, 2, 3]),
        },
      );
      const clip = MediaSource.asset('movie.mp4');

      await repo.preResolveAll([clip]);

      // No decode happened, so asking for a decoded image is the clear typed
      // error, not a decode crash.
      expect(
        () => repo.decodedImageFor(clip),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('movie.mp4')),
        ),
      );
    });
  });

  group('MediaRepository determinism', () {
    test('two repositories over identical inputs give equal content hashes', () async {
      final png = await _pngBytes();
      const source = MediaSource.asset('a.png');
      final a = _repo(assets: {'a.png': png});
      final b = _repo(assets: {'a.png': png});

      await a.preResolveAll([source]);
      await b.preResolveAll([source]);

      expect(a.resolvedFor(source).contentHash, b.resolvedFor(source).contentHash);
    });
  });

  group('MediaRepository.preResolveSnapshots + decodedSnapshotFor', () {
    const mermaid = SnapshotSource.mermaid('graph TD; A-->B');

    test('rasterizes and decodes a snapshot to a sync ui.Image', () async {
      final png = await _pngBytes();
      final repo = _repo();
      final service = _CountingSnapshotService(png);

      await repo.preResolveSnapshots([mermaid], service);
      final image = repo.decodedSnapshotFor(mermaid);

      expect(image.width, 2);
      expect(image.height, 2);
      expect(service.calls, 1);
    });

    test('decodes each raster once; the second pass is a cache hit', () async {
      final png = await _pngBytes();
      final repo = _repo();
      final service = _CountingSnapshotService(png);

      await repo.preResolveSnapshots([mermaid, mermaid], service);
      await repo.preResolveSnapshots([mermaid], service);

      expect(service.calls, 1, reason: 'cache must dedupe across and within calls');
    });

    test('decodedSnapshotFor before pre-resolve throws StateError', () {
      final repo = _repo();
      expect(
        () => repo.decodedSnapshotFor(mermaid),
        throwsA(isA<StateError>()),
      );
    });

    test('decodedSnapshotFor of an unresolved source throws a typed error', () async {
      final png = await _pngBytes();
      final repo = _repo();
      await repo.preResolveSnapshots([mermaid], _CountingSnapshotService(png));

      const other = SnapshotSource.mermaid('graph LR; X-->Y');
      expect(
        () => repo.decodedSnapshotFor(other),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('mermaid')),
        ),
      );
    });

    test('undecodable raster bytes surface a typed error from pre-resolve', () async {
      final repo = _repo();
      final service = _CountingSnapshotService(Uint8List.fromList([0, 1, 2, 3]));

      await expectLater(
        () => repo.preResolveSnapshots([mermaid], service),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('mermaid')),
        ),
      );
    });

    test('two value-equal sources share one decoded image (one rasterize)', () async {
      final png = await _pngBytes();
      final repo = _repo();
      final service = _CountingSnapshotService(png);
      const a = SnapshotSource.mermaid('graph TD; A-->B');
      const b = SnapshotSource.mermaid('graph TD; A-->B');

      await repo.preResolveSnapshots([a], service);
      await repo.preResolveSnapshots([b], service);

      expect(service.calls, 1, reason: 'an identical declaration must reuse the cached raster');
      expect(repo.decodedSnapshotFor(a), same(repo.decodedSnapshotFor(b)));
    });

    test('a fresh source sharing a cacheKey hits the cache (keyed by cacheKey)', () async {
      // The cache stores under source.cacheKey, so a distinct instance that
      // shares the same cacheKey must hit it: no extra rasterize, same image.
      // This pins the canonical key as the production cache key (decision
      // D-Source / D-ResolverGrow) rather than object identity. The payload is
      // built at runtime so the two instances are genuinely separate objects
      // (const-canonicalization cannot fold them).
      final png = await _pngBytes();
      final repo = _repo();
      final service = _CountingSnapshotService(png);
      final payload = 'shared payload ${['a', 'b'].join()}';
      final first = SnapshotSource.mermaid(payload, themeKey: 'dark');
      final second = SnapshotSource.mermaid(payload, themeKey: 'dark');
      expect(identical(first, second), isFalse, reason: 'guard: distinct instances');
      expect(first.cacheKey, second.cacheKey, reason: 'guard: they share a cacheKey');

      await repo.preResolveSnapshots([first], service);
      await repo.preResolveSnapshots([second], service);

      expect(service.calls, 1, reason: 'a shared cacheKey must hit the cache');
      expect(repo.decodedSnapshotFor(second), same(repo.decodedSnapshotFor(first)));
    });
  });

  group('MediaRepository.preResolveSnapshots URL allowlist gate (WI-14)', () {
    const viewport = SnapshotViewport(width: 320, height: 240);

    MediaRepository repoWith(NetworkAllowlist allowlist) => MediaRepository(
      loader: MediaBytesLoader(
        bundle: _MapBundle(const {}),
        httpClient: _CountingHttpClient(const {}),
        allowlist: allowlist,
      ),
    );

    test('a disallowed host throws a typed error before the service is reached', () async {
      final repo = repoWith(const NetworkAllowlist(hosts: {'example.com'}));
      final service = _NeverCalledSnapshotService();
      final source = SnapshotSource.url(
        Uri.parse('https://evil.test/page'),
        viewport: viewport,
      );

      await expectLater(
        () => repo.preResolveSnapshots([source], service),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('evil.test')),
        ),
      );
      expect(service.called, isFalse, reason: 'the allowlist must gate before any navigation');
    });

    test('a disallowed scheme throws before the service is reached', () async {
      final repo = repoWith(const NetworkAllowlist(hosts: {'example.com'}));
      final service = _NeverCalledSnapshotService();
      final source = SnapshotSource.url(
        Uri.parse('http://example.com/page'),
        viewport: viewport,
      );

      await expectLater(
        () => repo.preResolveSnapshots([source], service),
        throwsA(isA<FluvieRenderException>()),
      );
      expect(service.called, isFalse);
    });

    test('an allowed host proceeds to the service and decodes its raster', () async {
      final png = await _pngBytes();
      final repo = repoWith(const NetworkAllowlist(hosts: {'example.com'}));
      final service = _CountingSnapshotService(png);
      final source = SnapshotSource.url(
        Uri.parse('https://example.com/page'),
        viewport: viewport,
      );

      await repo.preResolveSnapshots([source], service);
      final image = repo.decodedSnapshotFor(source);

      expect(service.calls, 1);
      expect(image.width, 2);
    });

    test('a mermaid or html source does not touch the allowlist', () async {
      final png = await _pngBytes();
      // A host-empty allowlist would reject any URL; mermaid/html have no host.
      final repo = repoWith(const NetworkAllowlist(hosts: {}));
      final service = _CountingSnapshotService(png);
      const html = SnapshotSource.html('<p>hi</p>', viewport: viewport);
      const mermaid = SnapshotSource.mermaid('graph TD; A-->B');

      await repo.preResolveSnapshots([html, mermaid], service);

      expect(service.calls, 2, reason: 'local snapshots bypass the network gate');
    });
  });

  group('MediaRepository.dispose', () {
    test('disposes decoded image + snapshot caches and is idempotent', () async {
      final png = await _pngBytes();
      final repo = _repo(assets: {'a.png': png});
      const image = MediaSource.asset('a.png');
      const mermaid = SnapshotSource.mermaid('graph TD; A-->B');
      await repo.preResolveAll([image]);
      await repo.preResolveSnapshots([mermaid], _CountingSnapshotService(png));
      final decodedImage = repo.decodedImageFor(image);
      final decodedSnapshot = repo.decodedSnapshotFor(mermaid);

      expect(repo, isA<DisposableResolver>());
      repo.dispose();

      expect(decodedImage.debugDisposed, isTrue);
      expect(decodedSnapshot.debugDisposed, isTrue);
      expect(repo.dispose, returnsNormally, reason: 'a second dispose is a no-op');
    });
  });
}
