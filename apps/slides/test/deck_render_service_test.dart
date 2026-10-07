import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Aspect;
import 'package:fluvie/rendering.dart' show frameCountFor;
import 'package:slides/editor/deck_render_service.dart';

void main() {
  group('aspectForSize', () {
    test('maps the canonical canvas sizes onto their aspect family', () {
      expect(aspectForSize(1920, 1080), Aspect.landscape);
      expect(aspectForSize(1080, 1920), Aspect.reels);
      expect(aspectForSize(1080, 1080), Aspect.square);
      expect(aspectForSize(1080, 1350), Aspect.portrait45);
    });

    test('a wide canvas is landscape whatever its exact ratio', () {
      expect(aspectForSize(320, 180), Aspect.landscape);
      expect(aspectForSize(1000, 999), Aspect.landscape);
    });

    test('a tall canvas picks the nearest tall family', () {
      // 800x1000 is exactly 4:5.
      expect(aspectForSize(800, 1000), Aspect.portrait45);
      // 720x1280 is exactly 9:16.
      expect(aspectForSize(720, 1280), Aspect.reels);
      // Just barely taller than wide sits closer to 4:5 than 9:16.
      expect(aspectForSize(999, 1000), Aspect.portrait45);
    });

    test('the family size reproduces the canonical canvas exactly', () {
      expect(aspectForSize(1920, 1080).sizeFor(1920).height, 1080);
      expect(aspectForSize(1080, 1920).sizeFor(1920).width, 1080);
      expect(aspectForSize(1080, 1350).sizeFor(1350).width, 1080);
    });
  });

  test('the io platform service reports itself available', () {
    // Construction opens no dialog and starts no render; the render body
    // itself is faked in the journey tests.
    expect(DeckRenderService.platform().isAvailable, isTrue);
  });

  group('renderDurationFor', () {
    test('is the exact whole-video length', () {
      expect(renderDurationFor(90, 30), const Duration(seconds: 3));
      expect(renderDurationFor(30, 30), const Duration(seconds: 1));
    });

    test('round-trips through frameCountFor for every frame count', () {
      for (final fps in const [24, 30, 60]) {
        for (var frames = 1; frames <= 300; frames++) {
          expect(
            frameCountFor(renderDurationFor(frames, fps), fps),
            frames,
            reason: '$frames frames at $fps fps',
          );
        }
      }
    });
  });
}
