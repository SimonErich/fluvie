// WI-13 (D7, §15): ClipAudio is a data-only value type — the audio policy a
// Clip carries until the P13 audio pipeline consumes it. These pin the two
// factories' fields, defaults, and value equality.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/time.dart';

void main() {
  group('ClipAudio.included', () {
    test('defaults to full volume and no fade-in', () {
      const audio = ClipAudio.included();
      expect(audio.muted, isFalse);
      expect(audio.volume, 1.0);
      expect(audio.fadeIn, Time.zero);
    });

    test('carries the given volume and fade-in', () {
      const audio = ClipAudio.included(volume: 0.6, fadeIn: Time.seconds(0.3));
      expect(audio.muted, isFalse);
      expect(audio.volume, 0.6);
      expect(audio.fadeIn, const Time.seconds(0.3));
    });

    test('rejects a volume outside 0..1', () {
      expect(() => ClipAudio.included(volume: 1.5), throwsA(isA<AssertionError>()));
      expect(() => ClipAudio.included(volume: -0.1), throwsA(isA<AssertionError>()));
    });
  });

  group('ClipAudio.muted', () {
    test('mutes with zero volume and no fade', () {
      const audio = ClipAudio.muted();
      expect(audio.muted, isTrue);
      expect(audio.volume, 0.0);
      expect(audio.fadeIn, Time.zero);
    });
  });

  group('value equality', () {
    test('two included with the same fields are equal', () {
      expect(
        const ClipAudio.included(volume: 0.5, fadeIn: Time.frames(3)),
        const ClipAudio.included(volume: 0.5, fadeIn: Time.frames(3)),
      );
    });

    test('different volume is unequal', () {
      expect(
        const ClipAudio.included(volume: 0.5),
        isNot(const ClipAudio.included(volume: 0.6)),
      );
    });

    test('muted differs from a zero-volume included', () {
      expect(const ClipAudio.muted(), isNot(const ClipAudio.included(volume: 0)));
    });

    test('hashCode agrees with equality', () {
      expect(
        const ClipAudio.included(volume: 0.5).hashCode,
        const ClipAudio.included(volume: 0.5).hashCode,
      );
    });
  });

  test('toString names the policy', () {
    expect(const ClipAudio.muted().toString(), contains('muted'));
    expect(const ClipAudio.included(volume: 0.6).toString(), contains('0.6'));
  });
}
