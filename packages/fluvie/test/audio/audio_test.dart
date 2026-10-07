import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/trigger.dart';

void main() {
  group('Audio.music', () {
    test('carries every field verbatim', () {
      final beat = Anchor('beat');
      final trim = 2.seconds.to(10.seconds);
      final music = Audio.music(
        'song.mp3',
        volume: 0.8,
        fadeIn: 1.seconds,
        fadeOut: 2.seconds,
        loop: true,
        trim: trim,
        track: beat,
      );
      expect(music.source, 'song.mp3');
      expect(music.volume, 0.8);
      expect(music.fadeIn, 1.seconds);
      expect(music.fadeOut, 2.seconds);
      expect(music.loop, isTrue);
      expect(music.trim, same(trim));
      expect(music.track, same(beat));
    });

    test('defaults: full volume, no fades, no loop, no trim, no track', () {
      const music = Audio.music('song.mp3');
      expect(music.volume, 1);
      expect(music.fadeIn, isNull);
      expect(music.fadeOut, isNull);
      expect(music.loop, isFalse);
      expect(music.trim, isNull);
      expect(music.track, isNull);
      expect(music.at, isNull);
    });

    test('is not an sfx', () {
      expect(const Audio.music('song.mp3').isSfx, isFalse);
    });
  });

  group('Audio.sfx', () {
    test('carries source, trigger, and volume', () {
      final at = Trigger.at(1.seconds);
      final sfx = Audio.sfx('pop.wav', at: at, volume: 0.5);
      expect(sfx.source, 'pop.wav');
      expect(sfx.at, same(at));
      expect(sfx.volume, 0.5);
    });

    test('defaults: full volume, no trigger, no music-only fields', () {
      const sfx = Audio.sfx('pop.wav');
      expect(sfx.volume, 1);
      expect(sfx.at, isNull);
      expect(sfx.fadeIn, isNull);
      expect(sfx.fadeOut, isNull);
      expect(sfx.loop, isFalse);
      expect(sfx.trim, isNull);
      expect(sfx.track, isNull);
    });

    test('is an sfx, even without a trigger', () {
      expect(const Audio.sfx('pop.wav').isSfx, isTrue);
      expect(Audio.sfx('pop.wav', at: Trigger.at(1.seconds)).isSfx, isTrue);
    });
  });

  group('Audio.musicSource', () {
    test('carries the typed source and every music field verbatim', () {
      final beat = Anchor('beat');
      final trim = 2.seconds.to(10.seconds);
      final music = Audio.musicSource(
        const AudioSource.asset('audio/bed.mp3'),
        volume: 0.8,
        fadeIn: 1.seconds,
        fadeOut: 2.seconds,
        loop: true,
        trim: trim,
        track: beat,
      );
      expect(music.audioSource, const AudioSource.asset('audio/bed.mp3'));
      expect(music.source, 'audio/bed.mp3');
      expect(music.volume, 0.8);
      expect(music.fadeIn, 1.seconds);
      expect(music.fadeOut, 2.seconds);
      expect(music.loop, isTrue);
      expect(music.trim, same(trim));
      expect(music.track, same(beat));
      expect(music.isSfx, isFalse);
    });

    test('a memory source flows through untouched, bytes and all', () {
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      final source = AudioSource.memory(bytes, debugLabel: 'bed.mp3');
      final music = Audio.musicSource(source);
      expect(music.audioSource, same(source));
      expect((music.audioSource as MemoryAudioSource).bytes, same(bytes));
    });

    test('a memory source reads as a stable content-hashed source string', () {
      final source = AudioSource.memory(Uint8List.fromList(const [1, 2, 3]));
      final music = Audio.musicSource(source);
      expect(music.source, 'memory:${source.cacheKey}');
      expect(music.toString(), 'Audio.music(memory:${source.cacheKey})');
    });

    test('the string forms of the path-shaped kinds match the classifier', () {
      expect(const Audio.musicSource(AudioSource.file('/tmp/bed.mp3')).source, '/tmp/bed.mp3');
      expect(
        Audio.musicSource(AudioSource.network(Uri.parse('https://cdn.test/bed.mp3'))).source,
        'https://cdn.test/bed.mp3',
      );
    });
  });

  group('Audio.sfxSource', () {
    test('carries the typed source, trigger, and volume', () {
      final at = Trigger.at(1.seconds);
      final sfx = Audio.sfxSource(const AudioSource.asset('pop.wav'), at: at, volume: 0.5);
      expect(sfx.audioSource, const AudioSource.asset('pop.wav'));
      expect(sfx.source, 'pop.wav');
      expect(sfx.at, same(at));
      expect(sfx.volume, 0.5);
      expect(sfx.isSfx, isTrue);
    });

    test('a memory sfx carries its bytes with sfx defaults', () {
      final source = AudioSource.memory(Uint8List.fromList(const [7]));
      final sfx = Audio.sfxSource(source);
      expect(sfx.audioSource, same(source));
      expect(sfx.volume, 1);
      expect(sfx.at, isNull);
      expect(sfx.loop, isFalse);
      expect(sfx.trim, isNull);
    });
  });

  group('Audio.toString diagnostics', () {
    test('sfx names its source, trigger, and volume', () {
      final s = Audio.sfx('pop.wav', at: Trigger.at(1.seconds), volume: 0.5).toString();
      expect(s, startsWith('Audio.sfx(pop.wav'));
      expect(s, contains('volume: 0.5'));
    });

    test('music names only its source', () {
      expect(const Audio.music('song.mp3').toString(), 'Audio.music(song.mp3)');
    });
  });
}
