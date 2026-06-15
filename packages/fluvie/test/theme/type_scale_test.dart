// Epic 14.1 (WI-1, D-TypeScale): the §21 TypeScale value type. TypeScale.fromBase
// derives a ratio ladder of five roles (display / title / headline / body /
// caption) from a base size, has a fallback, and is value-equal by field.

import 'package:flutter/painting.dart' show TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/theme/type_scale.dart';

void main() {
  group('TypeScale.fromBase', () {
    test('derives all five roles as non-null TextStyles', () {
      final scale = TypeScale.fromBase(16);
      expect(scale.display, isA<TextStyle>());
      expect(scale.title, isA<TextStyle>());
      expect(scale.headline, isA<TextStyle>());
      expect(scale.body, isA<TextStyle>());
      expect(scale.caption, isA<TextStyle>());
    });

    test('body sits at the base size', () {
      final scale = TypeScale.fromBase(16);
      expect(scale.body.fontSize, 16);
    });

    test('orders the ladder display > title > headline > body > caption by size', () {
      final scale = TypeScale.fromBase(16);
      expect(scale.display.fontSize, greaterThan(scale.title.fontSize!));
      expect(scale.title.fontSize, greaterThan(scale.headline.fontSize!));
      expect(scale.headline.fontSize, greaterThan(scale.body.fontSize!));
      expect(scale.body.fontSize, greaterThan(scale.caption.fontSize!));
    });

    test('a larger ratio spreads the ladder further apart', () {
      final tight = TypeScale.fromBase(16, ratio: 1.15);
      final loose = TypeScale.fromBase(16, ratio: 1.5);
      expect(loose.display.fontSize, greaterThan(tight.display.fontSize!));
    });

    test('at the default ratio (1.25) the headline is one ratio step above body', () {
      final scale = TypeScale.fromBase(16);
      // The ladder is geometric: headline = body * ratio = 16 * 1.25 = 20.
      expect(scale.headline.fontSize, closeTo(20, 1e-9));
    });

    test('at the default ratio (1.25) the caption is one ratio step below body', () {
      final scale = TypeScale.fromBase(16);
      // caption = body / ratio = 16 / 1.25 = 12.8.
      expect(scale.caption.fontSize, closeTo(12.8, 1e-9));
    });
  });

  group('TypeScale.fallback', () {
    test('is a non-null scale with all five roles', () {
      const fallback = TypeScale.fallback();
      expect(fallback.display.fontSize, isNotNull);
      expect(fallback.title.fontSize, isNotNull);
      expect(fallback.headline.fontSize, isNotNull);
      expect(fallback.body.fontSize, isNotNull);
      expect(fallback.caption.fontSize, isNotNull);
    });

    test('is const-constructible (compile-time value)', () {
      expect(identical(const TypeScale.fallback(), const TypeScale.fallback()), isTrue);
    });
  });

  group('TypeScale — value equality', () {
    test('two scales from the same base are equal and share a hashCode', () {
      final a = TypeScale.fromBase(16);
      final b = TypeScale.fromBase(16);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('scales from a different base differ', () {
      expect(TypeScale.fromBase(16), isNot(TypeScale.fromBase(18)));
    });

    test('toString names the type', () {
      expect(const TypeScale.fallback().toString(), contains('TypeScale'));
    });
  });
}
