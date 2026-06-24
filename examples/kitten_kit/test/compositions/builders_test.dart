import 'package:flutter_test/flutter_test.dart';
import 'package:kitten_kit/kitten_kit.dart';

void main() {
  group('kittenPromo', () {
    test('builds a 5 second landscape HD promo with one scene', () {
      final video = kittenPromo(headline: 'Kitten Mitten', tagline: 'Cozy paws');

      expect(video.fps, 30);
      expect(video.totalFrames, 150);
      expect(video.width, greaterThan(video.height), reason: 'promo is landscape');
      expect(video.scenes, hasLength(1));
    });

    test('withMusic toggles the looping jingle bed', () {
      expect(kittenPromo(headline: 'x').audio, isNotEmpty);
      expect(kittenPromo(headline: 'x', withMusic: false).audio, isEmpty);
    });
  });

  group('birthdayCard', () {
    test('builds a 6 second square card with a music bed and a meow sfx', () {
      final video = birthdayCard(catName: 'Mittens');

      expect(video.fps, 30);
      expect(video.totalFrames, 180);
      expect(video.width, video.height, reason: 'card is square');
      expect(video.audio, hasLength(2), reason: 'music bed + one-shot meow');
    });
  });

  group('memePromo', () {
    test('builds a 4 second square meme', () {
      final video = memePromo(topText: 'when', bottomText: 'it is naptime');

      expect(video.fps, 30);
      expect(video.totalFrames, 120);
      expect(video.width, video.height, reason: 'meme is square');
      expect(video.audio, isNotEmpty);
    });
  });
}
