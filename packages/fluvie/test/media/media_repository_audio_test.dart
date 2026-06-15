import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';

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

class _CountingHttpClient implements MediaHttpClient {
  _CountingHttpClient(this._data);
  final Map<Uri, Uint8List> _data;
  int calls = 0;
  @override
  Future<Uint8List> get(Uri url) async {
    calls++;
    final bytes = _data[url];
    if (bytes == null) throw FluvieRenderException('no canned bytes for "$url"');
    return bytes;
  }
}

MediaRepository _repo({
  Map<String, Uint8List> assets = const {},
  MediaHttpClient? client,
  Map<Uri, Uint8List> network = const {},
  NetworkAllowlist? allowlist,
}) => MediaRepository(
  loader: MediaBytesLoader(
    bundle: _MapBundle(assets),
    httpClient: client ?? _CountingHttpClient(network),
    allowlist: allowlist ?? NetworkAllowlist.allowAny(),
  ),
);

void main() {
  final pcm = Uint8List.fromList(List.generate(64, (i) => i % 256));

  group('MediaRepository.preResolveAudio + materializedAudioPathFor', () {
    test('materializes an asset source to a file with its byte content', () async {
      final repo = _repo(assets: {'audio/song.mp3': pcm});
      const source = AudioSource.asset('audio/song.mp3');

      await repo.preResolveAudio(const [source]);
      final path = repo.materializedAudioPathFor(source);
      addTearDown(() => File(path).parent.deleteSync(recursive: true));

      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), pcm);
    });

    test('preResolveAudio is awaited and idempotent (one load per source)', () async {
      final client = _CountingHttpClient({Uri.parse('https://cdn.test/song.mp3'): pcm});
      final repo = _repo(client: client);
      final source = AudioSource.network(Uri.parse('https://cdn.test/song.mp3'));

      await repo.preResolveAudio([source]);
      final first = repo.materializedAudioPathFor(source);
      await repo.preResolveAudio([source]);
      final second = repo.materializedAudioPathFor(source);
      addTearDown(() => File(first).parent.deleteSync(recursive: true));

      expect(client.calls, 1);
      expect(second, first);
    });

    test('a disallowed network host throws naming the host, before any write', () async {
      final repo = _repo(
        client: _CountingHttpClient(const {}),
        allowlist: const NetworkAllowlist(hosts: {'allowed.test'}),
      );
      final source = AudioSource.network(Uri.parse('https://blocked.test/song.mp3'));

      await expectLater(
        repo.preResolveAudio([source]),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('blocked.test'),
          ),
        ),
      );
    });

    test('materializedAudioPathFor before preResolveAudio throws StateError', () {
      final repo = _repo();
      expect(
        () => repo.materializedAudioPathFor(const AudioSource.asset('song.mp3')),
        throwsStateError,
      );
    });

    test('materializedAudioPathFor for an unresolved source throws naming it', () async {
      final repo = _repo(assets: {'a.mp3': pcm});
      const a = AudioSource.asset('a.mp3');
      await repo.preResolveAudio(const [a]);
      addTearDown(() => File(repo.materializedAudioPathFor(a)).parent.deleteSync(recursive: true));

      expect(
        () => repo.materializedAudioPathFor(const AudioSource.asset('other.mp3')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('other.mp3')),
        ),
      );
    });
  });
}
