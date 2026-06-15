// Epic 10.1 (WI-12 value, D11): the FluvieTokens seam value + fallback. The
// const `FluvieTokens.fallback()` carries a non-empty series palette and
// axis/grid/label colors so charts have a real default before the scope and
// `context.fluvie` land in 10.4. Tokens are value-equal by field.

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/caption_style.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/palette.dart';
import 'package:fluvie/src/theme/type_scale.dart';

void main() {
  group('FluvieTokens.fallback', () {
    test('is const-constructible (compile-time value)', () {
      expect(identical(const FluvieTokens.fallback(), const FluvieTokens.fallback()), isTrue);
    });

    test('carries a non-empty ordered series palette', () {
      const tokens = FluvieTokens.fallback();
      expect(tokens.palette.colors, isNotEmpty);
      expect(tokens.palette.colors.length, greaterThan(1));
    });

    test('carries axis, grid, and label colors', () {
      const tokens = FluvieTokens.fallback();
      expect(tokens.axisColor, isA<Color>());
      expect(tokens.gridColor, isA<Color>());
      expect(tokens.labelColor, isA<Color>());
    });
  });

  group('FluvieTokens — construction and equality', () {
    test('takes an explicit palette and colors', () {
      const palette = ChartPalette([Color(0xFFFF0000), Color(0xFF00FF00)]);
      const tokens = FluvieTokens(
        palette: palette,
        axisColor: Color(0xFF111111),
        gridColor: Color(0xFF222222),
        labelColor: Color(0xFF333333),
      );
      expect(tokens.palette, palette);
      expect(tokens.axisColor, const Color(0xFF111111));
      expect(tokens.gridColor, const Color(0xFF222222));
      expect(tokens.labelColor, const Color(0xFF333333));
    });

    test('is value-equal by every field', () {
      const a = FluvieTokens.fallback();
      const b = FluvieTokens.fallback();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when any field differs', () {
      const base = FluvieTokens.fallback();
      final other = FluvieTokens(
        palette: base.palette,
        axisColor: const Color(0xFFABCDEF),
        gridColor: base.gridColor,
        labelColor: base.labelColor,
      );
      expect(base, isNot(other));
    });

    test('toString names the type', () {
      expect(const FluvieTokens.fallback().toString(), contains('FluvieTokens'));
    });
  });

  group('FluvieTokens — the §21 brand / type / motion fields (WI-2, D-Tokens-Grow)', () {
    test('the fallback carries a brand Palette, a TypeScale, and motion Defaults', () {
      const tokens = FluvieTokens.fallback();
      expect(tokens.brand, const Palette.fallback());
      expect(tokens.type, const TypeScale.fallback());
      expect(tokens.motion, const Defaults());
    });

    test('the new fields default so an existing call site compiles unchanged', () {
      // No brand / type / motion given — the unchanged 10.x call shape.
      const tokens = FluvieTokens(
        palette: ChartPalette([Color(0xFFFF0000)]),
        axisColor: Color(0xFF111111),
        gridColor: Color(0xFF222222),
        labelColor: Color(0xFF333333),
      );
      expect(tokens.brand, const Palette.fallback());
      expect(tokens.type, const TypeScale.fallback());
      expect(tokens.motion, const Defaults());
    });

    test('keeps the chart-series palette distinct from the brand palette', () {
      const tokens = FluvieTokens.fallback();
      // .palette is the chart-series ChartPalette; .brand is the §21 Palette.
      expect(tokens.palette, isA<ChartPalette>());
      expect(tokens.brand, isA<Palette>());
    });

    test('an explicit brand / type / motion is carried and changes equality', () {
      final tokens = FluvieTokens(
        palette: const ChartPalette([Color(0xFFFF0000)]),
        axisColor: const Color(0xFF111111),
        gridColor: const Color(0xFF222222),
        labelColor: const Color(0xFF333333),
        brand: const Palette(
          bg: Color(0xFF010101),
          accent: Color(0xFF00FF00),
          onBg: Color(0xFFFFFFFF),
        ),
        type: TypeScale.fromBase(18),
        motion: const Defaults(ease: Ease.out),
      );
      expect(tokens.brand.accent, const Color(0xFF00FF00));
      expect(tokens.type.body.fontSize, 18);
      expect(tokens.motion.ease, Ease.out);
      expect(tokens, isNot(const FluvieTokens.fallback()));
    });
  });

  group('FluvieTokens.copyWith (WI-2)', () {
    test('with no arguments returns an equal value', () {
      const base = FluvieTokens.fallback();
      expect(base.copyWith(), base);
    });

    test('merges only the brand, keeping every other field', () {
      const base = FluvieTokens.fallback();
      const brand = Palette(
        bg: Color(0xFF010101),
        accent: Color(0xFFABCDEF),
        onBg: Color(0xFFFFFFFF),
      );
      final copy = base.copyWith(brand: brand);
      expect(copy.brand, brand);
      expect(copy.palette, base.palette);
      expect(copy.type, base.type);
      expect(copy.motion, base.motion);
      expect(copy.code, base.code);
    });

    test('merges the type and motion independently', () {
      const base = FluvieTokens.fallback();
      final type = TypeScale.fromBase(20);
      const motion = Defaults(duration: Time.seconds(0.5));
      final copy = base.copyWith(type: type, motion: motion);
      expect(copy.type, type);
      expect(copy.motion, motion);
      expect(copy.brand, base.brand);
    });

    test('can replace the chart-series palette and the axis colors', () {
      const base = FluvieTokens.fallback();
      const palette = ChartPalette([Color(0xFF123456)]);
      final copy = base.copyWith(palette: palette, axisColor: const Color(0xFFAAAAAA));
      expect(copy.palette, palette);
      expect(copy.axisColor, const Color(0xFFAAAAAA));
    });
  });

  group('FluvieTokens — equality folds the new fields (WI-2)', () {
    test('differs when only the brand differs', () {
      const base = FluvieTokens.fallback();
      final other = base.copyWith(
        brand: const Palette(
          bg: Color(0xFF000000),
          accent: Color(0xFF010203),
          onBg: Color(0xFFFFFFFF),
        ),
      );
      expect(base, isNot(other));
      expect(base.hashCode, isNot(other.hashCode));
    });

    test('differs when only the motion differs', () {
      const base = FluvieTokens.fallback();
      final other = base.copyWith(motion: const Defaults(ease: Ease.bounce));
      expect(base, isNot(other));
    });
  });

  group('FluvieTokens.captions (D-CaptionTokens)', () {
    test('the fallback carries the standard caption theme by default', () {
      const tokens = FluvieTokens.fallback();
      expect(tokens.captions, const CaptionTheme.standard());
    });

    test('captions defaults to the standard theme when omitted (call sites compile)', () {
      const tokens = FluvieTokens(
        palette: ChartPalette([Color(0xFFFF0000)]),
        axisColor: Color(0xFF111111),
        gridColor: Color(0xFF222222),
        labelColor: Color(0xFF333333),
      );
      expect(tokens.captions, const CaptionTheme.standard());
    });

    test('an explicit caption theme is carried and changes equality', () {
      const tokens = FluvieTokens(
        palette: ChartPalette([Color(0xFFFF0000)]),
        axisColor: Color(0xFF111111),
        gridColor: Color(0xFF222222),
        labelColor: Color(0xFF333333),
        captions: CaptionTheme(defaultStyle: CaptionStyle.tikTok()),
      );
      expect(tokens.captions.defaultStyle, const CaptionStyle.tikTok());
      expect(tokens, isNot(const FluvieTokens.fallback()));
    });
  });
}
