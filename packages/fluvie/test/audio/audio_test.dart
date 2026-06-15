import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/core/anchor.dart';
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
