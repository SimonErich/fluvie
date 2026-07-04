import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show FluvieRenderException;
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._bytes);
  final Uint8List _bytes;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(_bytes);
  @override
  Future<String> loadString(String key, {bool cache = true}) async => utf8.decode(_bytes);
}

void main() {
  group('BundleWebAudioMaterializer', () {
    test('loads a bundled asset into bytes', () async {
      final bundle = _FakeBundle(Uint8List.fromList(const [1, 2, 3, 4]));
      final materializer = BundleWebAudioMaterializer(bundle: bundle);
      expect(await materializer.materialize('audio/song.mp3'), const [1, 2, 3, 4]);
    });

    test('fetches an allowlisted network source through the injected fetch', () async {
      var fetched = Uri();
      final materializer = BundleWebAudioMaterializer(
        allowlist: const NetworkAllowlist(hosts: {'cdn.fluvie.dev'}),
        fetch: (url) async {
          fetched = url;
          return Uint8List.fromList(const [9, 9]);
        },
      );
      final bytes = await materializer.materialize('https://cdn.fluvie.dev/bed.mp3');
      expect(bytes, const [9, 9]);
      expect(fetched, Uri.parse('https://cdn.fluvie.dev/bed.mp3'));
    });

    test('rejects a network source whose host is not allowlisted', () async {
      final materializer = BundleWebAudioMaterializer(
        allowlist: const NetworkAllowlist(hosts: {'cdn.fluvie.dev'}),
        fetch: (url) async => Uint8List(0),
      );
      await expectLater(
        materializer.materialize('https://evil.example.com/bed.mp3'),
        throwsA(isA<FluvieRenderException>()),
      );
    });

    test('rejects a network source when no allowlist is configured', () async {
      final materializer = BundleWebAudioMaterializer(fetch: (url) async => Uint8List(0));
      await expectLater(
        materializer.materialize('https://cdn.fluvie.dev/bed.mp3'),
        throwsA(isA<FluvieRenderException>()),
      );
    });

    test('rejects a local file source (no browser file system)', () async {
      final materializer = BundleWebAudioMaterializer(bundle: _FakeBundle(Uint8List(0)));
      await expectLater(
        materializer.materialize('/music/bed.wav'),
        throwsA(isA<FluvieRenderException>()),
      );
    });
  });
}
