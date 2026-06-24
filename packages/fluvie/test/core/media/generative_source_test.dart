import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/generative_kind.dart';
import 'package:fluvie/src/core/media/generative_source.dart';

void main() {
  group('GenerativeSource factories set their kind', () {
    test('video', () {
      const s = GenerativeSource.video(providerId: 'veo', prompt: 'a cat');
      expect(s.kind, GenerativeKind.video);
      expect(s.isVisual, isTrue);
      expect(s.isAudio, isFalse);
    });

    test('image', () {
      const s = GenerativeSource.image(providerId: 'flux', prompt: 'a cat');
      expect(s.kind, GenerativeKind.image);
      expect(s.isVisual, isTrue);
    });

    test('music / speech / soundEffect are audio', () {
      expect(const GenerativeSource.music(providerId: 'suno', prompt: 'x').isAudio, isTrue);
      expect(const GenerativeSource.speech(providerId: 'eleven', prompt: 'x').isAudio, isTrue);
      expect(
        const GenerativeSource.soundEffect(providerId: 'eleven', prompt: 'x').isAudio,
        isTrue,
      );
    });
  });

  group('GenerativeSource.cacheKey seed semantics', () {
    test('no seed → identical prompt yields one stable key', () {
      const a = GenerativeSource.image(providerId: 'flux', prompt: 'a cat');
      const b = GenerativeSource.image(providerId: 'flux', prompt: 'a cat');
      expect(a.cacheKey, b.cacheKey);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different seeds → different keys', () {
      const a = GenerativeSource.image(providerId: 'flux', prompt: 'a cat', seed: '1');
      const b = GenerativeSource.image(providerId: 'flux', prompt: 'a cat', seed: '2');
      expect(a.cacheKey, isNot(b.cacheKey));
      expect(a, isNot(b));
    });

    test('same seed → same key (deterministic per (prompt, seed))', () {
      const a = GenerativeSource.image(providerId: 'flux', prompt: 'a cat', seed: 'k');
      const b = GenerativeSource.image(providerId: 'flux', prompt: 'a cat', seed: 'k');
      expect(a.cacheKey, b.cacheKey);
    });

    test('key is path-safe (16 lowercase hex chars)', () {
      const a = GenerativeSource.image(providerId: 'flux', prompt: 'a cat');
      expect(a.cacheKey, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('provider, model, and kind all discriminate the key', () {
      const base = GenerativeSource.image(providerId: 'flux', prompt: 'p');
      expect(
        base.cacheKey,
        isNot(const GenerativeSource.image(providerId: 'openai', prompt: 'p').cacheKey),
      );
      expect(
        base.cacheKey,
        isNot(const GenerativeSource.image(providerId: 'flux', prompt: 'p', model: 'pro').cacheKey),
      );
      expect(
        base.cacheKey,
        isNot(const GenerativeSource.video(providerId: 'flux', prompt: 'p').cacheKey),
      );
    });
  });

  group('GenerativeSource params', () {
    test('param order does not change the key', () {
      const a = GenerativeSource.video(
        providerId: 'veo',
        prompt: 'p',
        params: {'seconds': 6, 'withAudio': true},
      );
      const b = GenerativeSource.video(
        providerId: 'veo',
        prompt: 'p',
        params: {'withAudio': true, 'seconds': 6},
      );
      expect(a.cacheKey, b.cacheKey);
      expect(a, b);
    });

    test('a changed param value changes the key', () {
      const a = GenerativeSource.video(providerId: 'veo', prompt: 'p', params: {'seconds': 6});
      const b = GenerativeSource.video(providerId: 'veo', prompt: 'p', params: {'seconds': 8});
      expect(a.cacheKey, isNot(b.cacheKey));
    });
  });

  test('toString names the kind and provider', () {
    const s = GenerativeSource.video(providerId: 'veo', prompt: 'hello', seed: 'z');
    expect(s.toString(), contains('video'));
    expect(s.toString(), contains('veo'));
  });
}
