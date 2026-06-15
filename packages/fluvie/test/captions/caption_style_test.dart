// WI-16 (D-Captions-types, §17): the CaptionStyle presets — tikTok/subtitle/
// karaoke carry a text style, a background, a highlight color, and the word-pop
// and karaoke flags the caption layer reads. Value-equal const so a styled
// track caches stably across builds.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/caption_style.dart';

void main() {
  group('CaptionStyle presets', () {
    test('tikTok pops words and is not karaoke', () {
      const style = CaptionStyle.tikTok();
      expect(style.wordPop, isTrue);
      expect(style.karaoke, isFalse);
      expect(style.textStyle.fontWeight, isNotNull);
    });

    test('subtitle is a plain, non-popping, non-karaoke style', () {
      const style = CaptionStyle.subtitle();
      expect(style.wordPop, isFalse);
      expect(style.karaoke, isFalse);
    });

    test('karaoke highlights the active word', () {
      const style = CaptionStyle.karaoke();
      expect(style.karaoke, isTrue);
    });

    test('each preset carries a background and a highlight color', () {
      for (final style in const [
        CaptionStyle.tikTok(),
        CaptionStyle.subtitle(),
        CaptionStyle.karaoke(),
      ]) {
        expect(style.background, isNotNull);
        expect(style.highlight, isNotNull);
      }
    });
  });

  group('CaptionStyle equality', () {
    test('a preset is value-equal to itself with a matching hashCode', () {
      expect(const CaptionStyle.tikTok(), const CaptionStyle.tikTok());
      expect(const CaptionStyle.tikTok().hashCode, const CaptionStyle.tikTok().hashCode);
    });

    test('different presets are not equal', () {
      expect(const CaptionStyle.tikTok(), isNot(const CaptionStyle.subtitle()));
      expect(const CaptionStyle.subtitle(), isNot(const CaptionStyle.karaoke()));
    });

    test('presets are const-constructible (compile-time values)', () {
      expect(identical(const CaptionStyle.tikTok(), const CaptionStyle.tikTok()), isTrue);
    });
  });
}
