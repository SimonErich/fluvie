import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

class _RecordingDelegate implements MobileAudioMaterializer {
  String? seen;
  @override
  Future<String> materialize(String source) async {
    seen = source;
    return '/delegated/$source';
  }
}

void main() {
  late Directory cacheDir;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('fluvie_net_audio_test_');
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  group('NetworkAudioMaterializer', () {
    test('fetches an allowlisted URL to a local file and returns its path', () async {
      Uri? fetched;
      final materializer = NetworkAudioMaterializer(
        allowlist: const NetworkAllowlist(hosts: {'cdn.fluvie.dev'}),
        cacheDir: cacheDir,
        fetch: (url) async {
          fetched = url;
          return Uint8List.fromList(const [1, 2, 3, 4]);
        },
      );

      final path = await materializer.materialize('https://cdn.fluvie.dev/bed.mp3');

      expect(fetched, Uri.parse('https://cdn.fluvie.dev/bed.mp3'));
      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), const [1, 2, 3, 4]);
    });

    test('rejects a URL whose host is not allowlisted, without fetching', () async {
      var fetchCalled = false;
      final materializer = NetworkAudioMaterializer(
        allowlist: const NetworkAllowlist(hosts: {'cdn.fluvie.dev'}),
        cacheDir: cacheDir,
        fetch: (url) async {
          fetchCalled = true;
          return Uint8List(0);
        },
      );

      await expectLater(
        materializer.materialize('https://evil.example.com/bed.mp3'),
        throwsA(isA<FluvieRenderException>()),
      );
      expect(fetchCalled, isFalse);
    });

    test('delegates a non-network source to the inner materializer', () async {
      final delegate = _RecordingDelegate();
      final materializer = NetworkAudioMaterializer(
        allowlist: const NetworkAllowlist(hosts: {'cdn.fluvie.dev'}),
        delegate: delegate,
        fetch: (url) async => Uint8List(0),
      );

      final path = await materializer.materialize('audio/song.mp3');

      expect(delegate.seen, 'audio/song.mp3');
      expect(path, '/delegated/audio/song.mp3');
    });
  });
}
