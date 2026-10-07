// The .cube 3D LUT parser. A LUT file is external input, so this is a
// validator first and a parser second: bounded size, a refusal per malformed
// shape, and nothing read past what the header declares.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

/// A legal 2-point identity cube.
const _identity2 = '''
TITLE "identity"
LUT_3D_SIZE 2

0.0 0.0 0.0
1.0 0.0 0.0
0.0 1.0 0.0
1.0 1.0 0.0
0.0 0.0 1.0
1.0 0.0 1.0
0.0 1.0 1.0
1.0 1.0 1.0
''';

void main() {
  group('a legal cube', () {
    test('parses its size and entries in red-fastest order', () {
      final lut = CubeLut.parse(_identity2);

      expect(lut.size, 2);
      expect(lut.rgb(0, 0, 0), (0.0, 0.0, 0.0));
      expect(lut.rgb(1, 0, 0), (1.0, 0.0, 0.0));
      expect(lut.rgb(0, 1, 0), (0.0, 1.0, 0.0));
      expect(lut.rgb(1, 1, 1), (1.0, 1.0, 1.0));
    });

    test('tolerates comments, blank lines and a title', () {
      final lut = CubeLut.parse('# a comment\n$_identity2# trailing\n');

      expect(lut.size, 2);
    });

    test('reads an authored domain', () {
      final lut = CubeLut.parse(
        'LUT_3D_SIZE 2\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n'
        '0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n',
      );

      expect(lut.size, 2);
    });

    test('the identity cube knows it is one', () {
      expect(CubeLut.parse(_identity2).isIdentity, isTrue);
    });
  });

  group('what it refuses', () {
    void refuses(String text, Pattern message) =>
        expect(() => CubeLut.parse(text), throwsA(predicate((e) => '$e'.contains(message))));

    test('a missing size declaration', () {
      refuses('0 0 0\n1 1 1\n', 'LUT_3D_SIZE');
    });

    test('a size outside the honest bounds', () {
      refuses('LUT_3D_SIZE 1\n0 0 0\n', 'between 2 and 64');
      refuses('LUT_3D_SIZE 65\n', 'between 2 and 64');
      refuses('LUT_3D_SIZE nope\n', 'between 2 and 64');
    });

    test('a truncated table', () {
      refuses('LUT_3D_SIZE 2\n0 0 0\n1 0 0\n', 'expected 8 entries, found 2');
    });

    test('a table with rows past the declared size', () {
      refuses('$_identity2\n0.5 0.5 0.5\n', 'expected 8 entries, found 9');
    });

    test('a long malformed row is clipped in the error, never echoed whole', () {
      final noise = 'A' * 500;
      try {
        CubeLut.parse('LUT_3D_SIZE 2\n$noise\n');
        fail('should refuse');
      } on Object catch (error) {
        expect('$error'.length, lessThan(200));
      }
    });

    test('a row that is not three numbers', () {
      refuses('LUT_3D_SIZE 2\n0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n', 'three');
      refuses(
        'LUT_3D_SIZE 2\n0 0 red\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n',
        'three',
      );
    });

    test('a value that is not a finite number', () {
      // NaN compares false to everything, so a naive range check passes it;
      // the validator must refuse what the bake could never encode.
      refuses(
        'LUT_3D_SIZE 2\nNaN NaN NaN\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n',
        'outside',
      );
      refuses(
        'LUT_3D_SIZE 2\n0 0 Infinity\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n',
        'outside',
      );
    });

    test('a value outside the unit domain', () {
      refuses(
        'LUT_3D_SIZE 2\n0 0 -2\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n',
        'outside',
      );
    });

    test('a domain other than the unit cube', () {
      refuses('LUT_3D_SIZE 2\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 2 1 1\n', 'unit domain');
    });

    test('an oversized file, before any parsing', () {
      final oversized = 'LUT_3D_SIZE 64\n${'0 0 0\n' * 800000}';

      refuses(oversized, 'too large');
    });
  });

  group('the baked texture', () {
    test('tiles the slices side by side, blue selecting the tile', () {
      final bytes = CubeLut.parse(_identity2).toRgbaBytes();

      // 2 slices of 2x2, tiled horizontally: 4x2 RGBA.
      expect(bytes, hasLength(4 * 2 * 4));
      // Pixel (0,0): r0 g0 b0 -> black, opaque.
      expect(bytes.sublist(0, 4), [0, 0, 0, 255]);
      // Pixel (1,0): r1 g0 b0 -> red.
      expect(bytes.sublist(4, 8), [255, 0, 0, 255]);
      // Second tile, pixel (2,0): r0 g0 b1 -> blue.
      expect(bytes.sublist(8, 12), [0, 0, 255, 255]);
      // Second row of first tile, pixel (0,1): r0 g1 b0 -> green.
      expect(bytes.sublist(16, 20), [0, 255, 0, 255]);
    });
  });
}
