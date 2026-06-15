// Epic 14.2 (WI-6, D-Aspect): the Aspect enum grows portrait45 (4:5) beside
// reels/square/landscape and gains sizeFor(longEdge) -> VideoSize. The enum is
// pure (no Flutter widgets); the BuildContext lookup lives on AspectScope and is
// covered by test/composition/runtime/aspect_scope_test.dart. sizeFor maps each
// family to its canonical VideoSize at a given long edge.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/video_size.dart';

void main() {
  group('Aspect values', () {
    test('carries reels, square, landscape and portrait45', () {
      expect(Aspect.values, [
        Aspect.reels,
        Aspect.square,
        Aspect.landscape,
        Aspect.portrait45,
      ]);
    });

    test('fallback is reels', () {
      expect(Aspect.fallback, Aspect.reels);
    });
  });

  group('Aspect.sizeFor', () {
    test('landscape is 16:9 with the long edge as width', () {
      expect(Aspect.landscape.sizeFor(1920), VideoSize.hd);
      expect(Aspect.landscape.sizeFor(3840), VideoSize.fourK);
    });

    test('reels is 9:16 with the long edge as height', () {
      expect(Aspect.reels.sizeFor(1920), VideoSize.reels);
    });

    test('square is 1:1 at the long edge on both axes', () {
      expect(Aspect.square.sizeFor(1080), VideoSize.square);
    });

    test('portrait45 is 4:5 with the long edge as height', () {
      expect(Aspect.portrait45.sizeFor(1350), const VideoSize(1080, 1350));
    });

    test('every aspect yields even dimensions (yuv420p safe)', () {
      for (final aspect in Aspect.values) {
        final size = aspect.sizeFor(1920);
        expect(size.width.isEven, isTrue, reason: '${aspect.name} width is odd');
        expect(size.height.isEven, isTrue, reason: '${aspect.name} height is odd');
      }
    });

    test('the long edge is the larger dimension for the non-square families', () {
      expect(Aspect.landscape.sizeFor(1280).width, 1280);
      expect(Aspect.reels.sizeFor(1280).height, 1280);
      expect(Aspect.portrait45.sizeFor(1280).height, 1280);
    });

    test('a non-positive long edge throws ArgumentError', () {
      expect(() => Aspect.square.sizeFor(0), throwsArgumentError);
      expect(() => Aspect.reels.sizeFor(-2), throwsArgumentError);
    });
  });
}
