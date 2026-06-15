// WI-17 (D-CaptionSource, §17): the sealed CaptionSource — .srt(path)/.vtt(path)/
// .inline(words). Value-equal with a stable cache key, mirroring AudioSource;
// the resolver reads + parses it once before frame 0.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/captions/caption_word.dart';
import 'package:fluvie/src/core/time_extensions.dart';

void main() {
  group('CaptionSource variants', () {
    test('srt carries the path', () {
      const source = CaptionSource.srt('en.srt');
      expect(source, isA<SrtCaptionSource>());
      expect((source as SrtCaptionSource).path, 'en.srt');
    });

    test('vtt carries the path', () {
      const source = CaptionSource.vtt('en.vtt');
      expect(source, isA<VttCaptionSource>());
      expect((source as VttCaptionSource).path, 'en.vtt');
    });

    test('inline carries the words', () {
      final words = [CaptionWord('Hi', at: 0.0.seconds)];
      final source = CaptionSource.inline(words);
      expect(source, isA<InlineCaptionSource>());
      expect((source as InlineCaptionSource).words, words);
    });
  });

  group('CaptionSource equality', () {
    test('two srt sources of one path are equal with a matching hashCode', () {
      expect(const CaptionSource.srt('en.srt'), const CaptionSource.srt('en.srt'));
      expect(
        const CaptionSource.srt('en.srt').hashCode,
        const CaptionSource.srt('en.srt').hashCode,
      );
    });

    test('srt and vtt of the same path are distinct', () {
      expect(const CaptionSource.srt('en'), isNot(const CaptionSource.vtt('en')));
    });

    test('different paths are distinct', () {
      expect(const CaptionSource.srt('en.srt'), isNot(const CaptionSource.srt('de.srt')));
    });

    test('inline sources are value-equal by their words', () {
      final a = CaptionSource.inline([CaptionWord('Hi', at: 0.0.seconds)]);
      final b = CaptionSource.inline([CaptionWord('Hi', at: 0.0.seconds)]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('CaptionSource.cacheKey', () {
    test('is a stable path-safe hex key', () {
      const source = CaptionSource.srt('en.srt');
      expect(source.cacheKey, source.cacheKey);
      expect(source.cacheKey, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('distinguishes the path and the format', () {
      expect(
        const CaptionSource.srt('en.srt').cacheKey,
        isNot(const CaptionSource.srt('de.srt').cacheKey),
      );
      expect(
        const CaptionSource.srt('en').cacheKey,
        isNot(const CaptionSource.vtt('en').cacheKey),
      );
    });
  });
}
