import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('MediaKind', () {
    test('has the six locked values', () {
      expect(MediaKind.values, hasLength(6));
      expect(MediaKind.values, [
        MediaKind.text,
        MediaKind.image,
        MediaKind.video,
        MediaKind.speech,
        MediaKind.soundEffect,
        MediaKind.music,
      ]);
    });

    test('isAudio is true only for speech, soundEffect, music', () {
      expect(MediaKind.speech.isAudio, isTrue);
      expect(MediaKind.soundEffect.isAudio, isTrue);
      expect(MediaKind.music.isAudio, isTrue);
      expect(MediaKind.text.isAudio, isFalse);
      expect(MediaKind.image.isAudio, isFalse);
      expect(MediaKind.video.isAudio, isFalse);
    });

    test('isVisual is true only for image and video', () {
      expect(MediaKind.image.isVisual, isTrue);
      expect(MediaKind.video.isVisual, isTrue);
      expect(MediaKind.text.isVisual, isFalse);
      expect(MediaKind.speech.isVisual, isFalse);
      expect(MediaKind.soundEffect.isVisual, isFalse);
      expect(MediaKind.music.isVisual, isFalse);
    });
  });
}
