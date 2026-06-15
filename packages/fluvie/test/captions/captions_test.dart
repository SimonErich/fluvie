import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/core/captions/caption_word.dart';
import 'package:fluvie/src/core/time_extensions.dart';

void main() {
  group('CaptionWord', () {
    test('carries text and time verbatim', () {
      final word = CaptionWord('Hello', at: 0.4.seconds);
      expect(word.text, 'Hello');
      expect(word.at, 0.4.seconds);
    });

    test('is value-equal with a matching hashCode', () {
      expect(CaptionWord('Hello', at: 0.4.seconds), CaptionWord('Hello', at: 0.4.seconds));
      expect(
        CaptionWord('Hello', at: 0.4.seconds).hashCode,
        CaptionWord('Hello', at: 0.4.seconds).hashCode,
      );
      expect(CaptionWord('Hello', at: 0.4.seconds), isNot(CaptionWord('world', at: 0.4.seconds)));
      expect(CaptionWord('Hello', at: 0.4.seconds), isNot(CaptionWord('Hello', at: 0.5.seconds)));
    });

    test('toString names text and time', () {
      expect(
        CaptionWord('Hello', at: 0.4.seconds).toString(),
        "CaptionWord('Hello', at: ${0.4.seconds})",
      );
    });
  });

  group('Captions', () {
    test('fromSrt stores the path verbatim with no words', () {
      const captions = Captions.fromSrt('en.srt');
      expect(captions.source, 'en.srt');
      expect(captions.words, isEmpty);
    });

    test('fromVtt stores the path verbatim with no words', () {
      const captions = Captions.fromVtt('en.vtt');
      expect(captions.source, 'en.vtt');
      expect(captions.words, isEmpty);
    });

    test('words stores the word list verbatim with no source', () {
      final hello = CaptionWord('Hello', at: 0.0.seconds);
      final world = CaptionWord('world', at: 0.4.seconds);
      final captions = Captions.words([hello, world]);
      expect(captions.source, isNull);
      expect(captions.words, [hello, world]);
    });

    test('the words list is unmodifiable', () {
      final captions = Captions.words([CaptionWord('Hello', at: 0.0.seconds)]);
      expect(() => captions.words.add(CaptionWord('!', at: 1.seconds)), throwsUnsupportedError);
      expect(captions.words.clear, throwsUnsupportedError);
    });

    test('the words list does not alias the caller list', () {
      final source = [CaptionWord('Hello', at: 0.0.seconds)];
      final captions = Captions.words(source);
      source.add(CaptionWord('!', at: 1.seconds));
      expect(captions.words, hasLength(1));
    });
  });
}
