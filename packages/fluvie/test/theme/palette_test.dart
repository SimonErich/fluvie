// Epic 14.1 (WI-1, D-Palette): the §21 brand Palette value type. A Palette
// carries the bg / accent / onBg trio plus optional surface / onSurface, has a
// dark-neutral fallback, is value-equal by field, and copyWith merges. This is
// the BRAND palette (FluvieTokens.brand) — distinct from the chart-series
// ChartPalette (FluvieTokens.palette).

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/theme/palette.dart';

void main() {
  group('Palette — construction', () {
    test('carries the required bg / accent / onBg colors', () {
      const palette = Palette(
        bg: Color(0xFF0E0E12),
        accent: Color(0xFF6C5CE7),
        onBg: Color(0xFFFFFFFF),
      );
      expect(palette.bg, const Color(0xFF0E0E12));
      expect(palette.accent, const Color(0xFF6C5CE7));
      expect(palette.onBg, const Color(0xFFFFFFFF));
    });

    test('surface and onSurface are optional (null by default)', () {
      const palette = Palette(
        bg: Color(0xFF0E0E12),
        accent: Color(0xFF6C5CE7),
        onBg: Color(0xFFFFFFFF),
      );
      expect(palette.surface, isNull);
      expect(palette.onSurface, isNull);
    });

    test('carries explicit surface and onSurface', () {
      const palette = Palette(
        bg: Color(0xFF0E0E12),
        accent: Color(0xFF6C5CE7),
        onBg: Color(0xFFFFFFFF),
        surface: Color(0xFF1A1A20),
        onSurface: Color(0xFFCCCCCC),
      );
      expect(palette.surface, const Color(0xFF1A1A20));
      expect(palette.onSurface, const Color(0xFFCCCCCC));
    });
  });

  group('Palette.fallback', () {
    test('is a non-null dark neutral with real colors', () {
      const fallback = Palette.fallback();
      expect(fallback.bg, isA<Color>());
      expect(fallback.accent, isA<Color>());
      expect(fallback.onBg, isA<Color>());
    });

    test('is const-constructible (compile-time value)', () {
      expect(identical(const Palette.fallback(), const Palette.fallback()), isTrue);
    });

    test('onBg reads light against the dark bg (a usable default contrast)', () {
      const fallback = Palette.fallback();
      // A dark neutral: the background is darker than the foreground text.
      expect(fallback.bg.computeLuminance(), lessThan(fallback.onBg.computeLuminance()));
    });
  });

  group('Palette — value equality', () {
    test('two identical palettes are equal and share a hashCode', () {
      const a = Palette(bg: Color(0xFF000000), accent: Color(0xFF00FF00), onBg: Color(0xFFFFFFFF));
      const b = Palette(bg: Color(0xFF000000), accent: Color(0xFF00FF00), onBg: Color(0xFFFFFFFF));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when any field differs', () {
      const base = Palette(
        bg: Color(0xFF000000),
        accent: Color(0xFF00FF00),
        onBg: Color(0xFFFFFFFF),
      );
      const other = Palette(
        bg: Color(0xFF000000),
        accent: Color(0xFFFF0000),
        onBg: Color(0xFFFFFFFF),
      );
      expect(base, isNot(other));
    });

    test('toString names the type', () {
      expect(const Palette.fallback().toString(), contains('Palette'));
    });
  });

  group('Palette.copyWith', () {
    test('merges only the given field, keeping the rest', () {
      const base = Palette(
        bg: Color(0xFF000000),
        accent: Color(0xFF00FF00),
        onBg: Color(0xFFFFFFFF),
      );
      final copy = base.copyWith(accent: const Color(0xFFFF0000));
      expect(copy.accent, const Color(0xFFFF0000));
      expect(copy.bg, base.bg);
      expect(copy.onBg, base.onBg);
    });

    test('with no arguments returns an equal palette', () {
      const base = Palette.fallback();
      expect(base.copyWith(), base);
    });

    test('can set the optional surface colors', () {
      const base = Palette.fallback();
      final copy = base.copyWith(
        surface: const Color(0xFF222222),
        onSurface: const Color(0xFFDDDDDD),
      );
      expect(copy.surface, const Color(0xFF222222));
      expect(copy.onSurface, const Color(0xFFDDDDDD));
    });
  });
}
