import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

void main() {
  group('AudioSource factories', () {
    test('asset wraps a bundle key', () {
      const source = AudioSource.asset('audio/song.mp3');
      expect(source, isA<AssetAudioSource>());
      expect((source as AssetAudioSource).name, 'audio/song.mp3');
    });

    test('file wraps a disk path', () {
      const source = AudioSource.file('/tmp/song.mp3');
      expect(source, isA<FileAudioSource>());
      expect((source as FileAudioSource).path, '/tmp/song.mp3');
    });

    test('network carries the Uri', () {
      final source = AudioSource.network(Uri.parse('https://cdn.example.com/song.mp3'));
      expect(source, isA<NetworkAudioSource>());
      expect((source as NetworkAudioSource).url, Uri.parse('https://cdn.example.com/song.mp3'));
    });

    test('network exposes the URL host for the allowlist check', () {
      final source = AudioSource.network(Uri.parse('https://cdn.example.com/song.mp3'));
      expect((source as NetworkAudioSource).host, 'cdn.example.com');
    });
  });

  group('AudioSource value equality', () {
    test('asset == asset for the same name', () {
      expect(const AudioSource.asset('a.mp3'), const AudioSource.asset('a.mp3'));
      expect(
        const AudioSource.asset('a.mp3').hashCode,
        const AudioSource.asset('a.mp3').hashCode,
      );
    });

    test('asset differs when the name differs', () {
      expect(const AudioSource.asset('a.mp3'), isNot(const AudioSource.asset('b.mp3')));
    });

    test('file == file for the same path', () {
      expect(const AudioSource.file('/a.mp3'), const AudioSource.file('/a.mp3'));
    });

    test('network == network for the same url', () {
      expect(
        AudioSource.network(Uri.parse('https://h/a.mp3')),
        AudioSource.network(Uri.parse('https://h/a.mp3')),
      );
    });

    test('an asset is never equal to a file with the same string', () {
      expect(const AudioSource.asset('a.mp3'), isNot(const AudioSource.file('a.mp3')));
    });
  });

  group('AudioSource.cacheKey', () {
    test('is stable across identical sources', () {
      expect(const AudioSource.asset('a.mp3').cacheKey, const AudioSource.asset('a.mp3').cacheKey);
    });

    test('is 16 lower-case hex characters', () {
      final key = const AudioSource.asset('a.mp3').cacheKey;
      expect(key, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('distinguishes different paths', () {
      expect(
        const AudioSource.file('/a.mp3').cacheKey,
        isNot(const AudioSource.file('/b.mp3').cacheKey),
      );
    });

    test('distinguishes different hosts', () {
      expect(
        AudioSource.network(Uri.parse('https://a.com/x.mp3')).cacheKey,
        isNot(AudioSource.network(Uri.parse('https://b.com/x.mp3')).cacheKey),
      );
    });

    test('distinguishes a variant from another with the same string', () {
      expect(
        const AudioSource.asset('a.mp3').cacheKey,
        isNot(const AudioSource.file('a.mp3').cacheKey),
      );
    });
  });

  group('AudioSource.toString', () {
    test('names the variant and target', () {
      expect(const AudioSource.asset('a.mp3').toString(), 'AudioSource.asset(a.mp3)');
      expect(const AudioSource.file('/a.mp3').toString(), 'AudioSource.file(/a.mp3)');
      expect(
        AudioSource.network(Uri.parse('https://h/a.mp3')).toString(),
        'AudioSource.network(https://h/a.mp3)',
      );
    });
  });

  group('Audio.audioSource resolves the string by shape', () {
    test('an https URL resolves to a network source', () {
      const audio = Audio.music('https://cdn.example.com/song.mp3');
      final source = audio.audioSource;
      expect(source, isA<NetworkAudioSource>());
      expect((source as NetworkAudioSource).url, Uri.parse('https://cdn.example.com/song.mp3'));
    });

    test('an http URL resolves to a network source', () {
      const audio = Audio.music('http://cdn.example.com/song.mp3');
      expect(audio.audioSource, isA<NetworkAudioSource>());
    });

    test('an absolute path resolves to a file source', () {
      const audio = Audio.sfx('/var/media/pop.wav');
      final source = audio.audioSource;
      expect(source, isA<FileAudioSource>());
      expect((source as FileAudioSource).path, '/var/media/pop.wav');
    });

    test('a bare bundle key resolves to an asset source', () {
      const audio = Audio.music('audio/song.mp3');
      final source = audio.audioSource;
      expect(source, isA<AssetAudioSource>());
      expect((source as AssetAudioSource).name, 'audio/song.mp3');
    });

    test('an empty source is a render error', () {
      expect(() => const Audio.music('').audioSource, throwsA(isA<Object>()));
    });

    test('an https URL with no host is a render error naming the missing host', () {
      expect(
        () => const Audio.music('https:///path/to/song.mp3').audioSource,
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('no host'),
          ),
        ),
      );
    });

    test('an http URL with no host is a render error too', () {
      expect(
        () => const Audio.sfx('http:///pop.wav').audioSource,
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('no host'),
          ),
        ),
      );
    });

    test('the resolved source is stable across reads', () {
      const audio = Audio.music('audio/song.mp3');
      expect(audio.audioSource, audio.audioSource);
    });
  });
}
