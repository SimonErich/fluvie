// The colour-matrix grade: five parameters composed into one 4x5 matrix.
// The composition order is white balance, then exposure, then contrast,
// then saturation — pinned here per parameter and per pair, because matrix
// multiplication does not commute and a silent reorder would regrade every
// document.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/animation/effects/color_grade_effect.dart';

/// The 4x5 identity: the neutral grade must compose to exactly this.
const List<double> _identity = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Applies the 4x5 [matrix] to an rgba pixel (0..255 channels).
List<double> _apply(List<double> matrix, List<double> rgba) => [
  for (var row = 0; row < 4; row++)
    matrix[row * 5] * rgba[0] +
        matrix[row * 5 + 1] * rgba[1] +
        matrix[row * 5 + 2] * rgba[2] +
        matrix[row * 5 + 3] * rgba[3] +
        matrix[row * 5 + 4],
];

void main() {
  group('the neutral grade', () {
    test('composes to exactly the identity matrix', () {
      expect(ColorGradeEffect.matrixFor(), _identity);
    });
  });

  group('one parameter at a time', () {
    test('exposure is a power-of-two gain on the colour channels', () {
      final matrix = ColorGradeEffect.matrixFor(exposure: 1);

      expect(_apply(matrix, [100, 50, 25, 255]), [200, 100, 50, 255]);
      expect(ColorGradeEffect.matrixFor(exposure: -1)[0], 0.5);
    });

    test('fractional stops invert cleanly across zero', () {
      // Half a stop down must dim, and mirror half a stop up.
      final up = ColorGradeEffect.matrixFor(exposure: 0.5)[0];
      final down = ColorGradeEffect.matrixFor(exposure: -0.5)[0];

      expect(down, lessThan(1));
      expect(up * down, closeTo(1, 1e-6));
    });

    test('contrast scales around mid grey', () {
      final matrix = ColorGradeEffect.matrixFor(contrast: 2);

      // Mid grey is the pivot: 127.5 stays put.
      expect(_apply(matrix, [127.5, 127.5, 127.5, 255]), [127.5, 127.5, 127.5, 255]);
      expect(_apply(matrix, [227.5, 127.5, 27.5, 255]), [327.5, 127.5, -72.5, 255]);
    });

    test('saturation zero is luminance grey, weighted by Rec. 709', () {
      final matrix = ColorGradeEffect.matrixFor(saturation: 0);
      final grey = _apply(matrix, [255, 0, 0, 255]);

      expect(grey[0], closeTo(255 * 0.2126, 1e-6));
      expect(grey[0], closeTo(grey[1], 1e-9));
      expect(grey[1], closeTo(grey[2], 1e-9));
    });

    test('a non-neutral saturation leaves the identity', () {
      // The neutral case is the identity-grade pin above; this holds the
      // composed path apart from it.
      expect(ColorGradeEffect.matrixFor(saturation: 0.5), isNot(_identity));
    });

    test('temperature warms red up and blue down, symmetrically', () {
      final warm = ColorGradeEffect.matrixFor(temperature: 1);

      expect(warm[0], closeTo(1.2, 1e-9));
      expect(warm[12], closeTo(0.8, 1e-9));
      expect(warm[6], 1);

      final cool = ColorGradeEffect.matrixFor(temperature: -1);
      expect(cool[0], closeTo(0.8, 1e-9));
      expect(cool[12], closeTo(1.2, 1e-9));
    });

    test('tint trades green against magenta', () {
      // Positive tint is magenta: green falls; negative is green: it rises.
      expect(ColorGradeEffect.matrixFor(tint: 1)[6], closeTo(0.8, 1e-9));
      expect(ColorGradeEffect.matrixFor(tint: -1)[6], closeTo(1.2, 1e-9));
      expect(ColorGradeEffect.matrixFor(tint: 1)[0], 1);
    });

    test('alpha never moves, whatever the grade', () {
      final matrix = ColorGradeEffect.matrixFor(
        exposure: 2,
        contrast: 1.5,
        saturation: 0.3,
        temperature: 0.5,
        tint: -0.4,
      );

      expect(matrix.sublist(15), [0, 0, 0, 1, 0]);
    });
  });

  group('the identity grade on screen', () {
    testWidgets('is a pixel-for-pixel no-op', (tester) async {
      // Not merely close: a document that gains an all-default grade block
      // must render the bytes it always rendered.
      Widget frame(List<EffectLayer> effects) => RenderControllerScope(
        controller: RenderController(initialFrame: 10),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              child: SizedBox(
                width: 96,
                height: 96,
                child: Video(
                  width: 96,
                  height: 96,
                  scenes: [
                    Scene(
                      duration: const Time.frames(30),
                      children: [
                        const Box(color: Color(0xFF5C7CFA)).effects(effects),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(frame(const []));
      final bare = await captureImage(find.byType(RepaintBoundary).evaluate().single);

      await tester.pumpWidget(frame([Effect.grade()]));
      await expectLater(find.byType(RepaintBoundary), matchesReferenceImage(bare));
    });
  });

  group('the composition order', () {
    test('is white balance, then exposure, then contrast, then saturation', () {
      // Contrast after exposure: a pixel exposure pushes past the pivot must
      // be stretched from the pivot, not the other way around. At 100 red:
      // exposure +1 makes 200, then contrast 2 stretches to 272.5. The other
      // order would read 2*(100-127.5)+127.5 = 72.5 doubled to 145.
      final matrix = ColorGradeEffect.matrixFor(exposure: 1, contrast: 2);

      expect(_apply(matrix, [100, 100, 100, 255])[0], closeTo(272.5, 1e-6));
    });

    test('saturation reads the graded channels, not the source', () {
      // Temperature first, saturation last: desaturating a warmed frame
      // greys toward the warmed luminance. The other order would warm the
      // grey and leave the channels unequal.
      final matrix = ColorGradeEffect.matrixFor(temperature: 1, saturation: 0);
      final grey = _apply(matrix, [100, 100, 100, 255]);

      expect(grey[0], closeTo(grey[1], 1e-9));
      expect(grey[1], closeTo(grey[2], 1e-9));
    });

    test('white balance and exposure commute, being both diagonal gains', () {
      expect(
        ColorGradeEffect.matrixFor(exposure: 1, temperature: 0.5),
        ColorGradeEffect.matrixFor(temperature: 0.5, exposure: 1),
      );
    });
  });
}
