import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';

/// An [AssetBundle] serving a fixed `key -> bytes` map.
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

/// A [MediaHttpClient] serving a fixed `url -> bytes` map; records each fetch.
class _RecordingHttpClient implements MediaHttpClient {
  _RecordingHttpClient(this._data);

  final Map<Uri, Uint8List> _data;
  final List<Uri> fetched = [];

  @override
  Future<Uint8List> get(Uri url) async {
    fetched.add(url);
    final bytes = _data[url];
    if (bytes == null) {
      throw FluvieRenderException('no canned bytes for "$url"');
    }
    return bytes;
  }
}

MediaBytesLoader _loader({
  Map<String, Uint8List> assets = const {},
  Map<Uri, Uint8List> network = const {},
  MediaHttpClient? client,
  NetworkAllowlist? allowlist,
  Future<Uint8List> Function(String path)? readFile,
  bool blockFileSources = false,
}) => MediaBytesLoader(
  bundle: _MapBundle(assets),
  httpClient: client ?? _RecordingHttpClient(network),
  allowlist: allowlist ?? NetworkAllowlist.allowAny(),
  readFile: readFile,
  blockFileSources: blockFileSources,
);

void main() {
  group('MediaBytesLoader.load', () {
    test('asset key resolves to bundle bytes', () async {
      final loader = _loader(
        assets: {
          'logo.png': Uint8List.fromList([1, 2, 3]),
        },
      );
      expect(await loader.load(const MediaSource.asset('logo.png')), [1, 2, 3]);
    });

    test('a missing asset key throws a typed error naming it', () async {
      final loader = _loader();
      await expectLater(
        () => loader.load(const MediaSource.asset('absent.png')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('absent.png')),
        ),
      );
    });

    test('file path resolves to file bytes', () async {
      final dir = Directory.systemTemp.createTempSync('fluvie_loader_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/photo.bin')..writeAsBytesSync([4, 5, 6]);
      final loader = _loader();
      expect(await loader.load(MediaSource.file(file.path)), [4, 5, 6]);
    });

    test('blockFileSources rejects a FileSource without reading it', () async {
      final dir = Directory.systemTemp.createTempSync('fluvie_loader_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/secret.bin')..writeAsBytesSync([7]);
      var read = false;
      final loader = _loader(
        blockFileSources: true,
        readFile: (path) async {
          read = true;
          return Uint8List.fromList([7]);
        },
      );
      await expectLater(
        () => loader.load(MediaSource.file(file.path)),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('not allowed'),
          ),
        ),
      );
      expect(read, isFalse, reason: 'the file must never be read');
    });

    test('a mid-read failure on an existing file is wrapped, naming the path', () async {
      // The file exists (so the existence guard passes); the read seam throws,
      // landing in the typed-wrap catch. This is the existing-but-unreadable
      // case (a permission error mid-read), driven deterministically.
      final dir = Directory.systemTemp.createTempSync('fluvie_loader_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/locked.bin')..writeAsBytesSync([0]);
      final loader = _loader(
        readFile: (path) async => throw const FileSystemException('Permission denied'),
      );
      await expectLater(
        () => loader.load(MediaSource.file(file.path)),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains(file.path))
              .having((e) => e.message, 'message', contains('Permission denied')),
        ),
      );
    });

    test('a missing file throws a typed error naming the path', () async {
      final loader = _loader();
      await expectLater(
        () => loader.load(const MediaSource.file('/no/such/file.bin')),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('/no/such/file.bin'),
          ),
        ),
      );
    });

    test('network source goes through the http client after the allowlist passes', () async {
      final url = Uri.parse('https://example.com/c.png');
      final client = _RecordingHttpClient({
        url: Uint8List.fromList([7, 8]),
      });
      final loader = _loader(
        client: client,
        allowlist: const NetworkAllowlist(hosts: {'example.com'}),
      );

      expect(await loader.load(MediaSource.network(url)), [7, 8]);
      expect(client.fetched, [url]);
    });

    test('a disallowed network host throws before any fetch', () async {
      final url = Uri.parse('https://evil.test/c.png');
      final client = _RecordingHttpClient(const {});
      final loader = _loader(
        client: client,
        allowlist: const NetworkAllowlist(hosts: {'example.com'}),
      );

      await expectLater(
        () => loader.load(MediaSource.network(url)),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('evil.test')),
        ),
      );
      expect(client.fetched, isEmpty, reason: 'allowlist must gate before fetch');
    });

    test('memory source returns its bytes verbatim with no IO', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final loader = _loader();
      expect(await loader.load(MediaSource.memory(bytes)), same(bytes));
    });
  });
}
