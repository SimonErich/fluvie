// WI-18 (D-Captions, D-CaptionSource, §17): Captions.fromSrt/fromVtt/words grow
// {style, position} and expose a CaptionSource for the collect pass. The inert
// data from P6.1 keeps compiling — the new params are optional.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/caption_position.dart';
import 'package:fluvie/src/captions/caption_style.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/captions/caption_word.dart';
import 'package:fluvie/src/core/time_extensions.dart';

void main() {
  group('Captions exposes a CaptionSource', () {
    test('fromSrt resolves to an SRT source carrying the path', () {
      const captions = Captions.fromSrt('en.srt');
      expect(captions.captionSource, const CaptionSource.srt('en.srt'));
    });

    test('fromVtt resolves to a VTT source carrying the path', () {
      const captions = Captions.fromVtt('en.vtt');
      expect(captions.captionSource, const CaptionSource.vtt('en.vtt'));
    });

    test('words resolves to an inline source needing no IO', () {
      final words = [CaptionWord('Hi', at: 0.0.seconds)];
      final captions = Captions.words(words);
      expect(captions.captionSource, isA<InlineCaptionSource>());
      expect((captions.captionSource as InlineCaptionSource).words, words);
    });
  });

  group('Captions carries style and position', () {
    test('fromSrt takes an optional style and position', () {
      const captions = Captions.fromSrt(
        'en.srt',
        style: CaptionStyle.tikTok(),
        position: CaptionPosition.topThird(),
      );
      expect(captions.style, const CaptionStyle.tikTok());
      expect(captions.position, const CaptionPosition.topThird());
    });

    test('fromVtt takes an optional style and position', () {
      const captions = Captions.fromVtt(
        'en.vtt',
        style: CaptionStyle.karaoke(),
        position: CaptionPosition.center(),
      );
      expect(captions.style, const CaptionStyle.karaoke());
      expect(captions.position, const CaptionPosition.center());
    });

    test('the existing inert calls keep compiling with no style or position', () {
      const srt = Captions.fromSrt('en.srt');
      const vtt = Captions.fromVtt('en.vtt');
      final inline = Captions.words([CaptionWord('Hi', at: 0.0.seconds)]);
      expect(srt.style, isNull);
      expect(vtt.position, isNull);
      expect(inline.style, isNull);
    });

    test('words takes an optional style and position', () {
      final captions = Captions.words(
        [CaptionWord('Hi', at: 0.0.seconds)],
        style: const CaptionStyle.subtitle(),
        position: const CaptionPosition.bottomThird(),
      );
      expect(captions.style, const CaptionStyle.subtitle());
      expect(captions.position, const CaptionPosition.bottomThird());
    });
  });
}
