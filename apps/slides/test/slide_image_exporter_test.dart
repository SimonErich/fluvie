import 'package:flutter_test/flutter_test.dart';
import 'package:slides/editor/slide_image_exporter.dart';

void main() {
  group('slideImageFileName', () {
    test('numbers slides from one with two digits', () {
      expect(slideImageFileName('deck', 0, 5), 'deck-01.png');
      expect(slideImageFileName('deck', 4, 5), 'deck-05.png');
    });

    test('grows the padding with the deck', () {
      expect(slideImageFileName('deck', 0, 100), 'deck-001.png');
      expect(slideImageFileName('deck', 99, 100), 'deck-100.png');
    });

    test('keeps the base name verbatim', () {
      expect(slideImageFileName('My Talk', 0, 2), 'My Talk-01.png');
    });
  });

  test('the platform factory builds an exporter without touching a dialog', () {
    expect(SlideImageExporter.platform(), isA<SlideImageExporter>());
  });
}
