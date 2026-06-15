// Epic 14.1 (WI-3, D-FluvieTheme): FluvieTheme mounts a FluvieTokensScope over
// the nearest tokens, overriding only brand / type / motion. context.fluvie
// resolves the themed values; nested themes override; a subtree with no theme
// reads the fallback; an explicit palette sets only .brand (the chart-series
// .palette is unchanged). This CLOSES the FluvieTokens seam: FluvieTheme is the
// scope the production tree reads.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/theme/fluvie_theme.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/palette.dart';
import 'package:fluvie/src/theme/type_scale.dart';

const _brand = Palette(
  bg: Color(0xFF0E0E12),
  accent: Color(0xFF6C5CE7),
  onBg: Color(0xFFFFFFFF),
);

const _other = Palette(
  bg: Color(0xFF202020),
  accent: Color(0xFFFF0000),
  onBg: Color(0xFFEEEEEE),
);

/// Mounts a probe inside [wrap] and captures the [FluvieTokens] at its context.
Future<FluvieTokens> _tokensVia(
  WidgetTester tester,
  Widget Function(Widget probe) wrap,
) async {
  late FluvieTokens seen;
  await tester.pumpWidget(
    wrap(
      Builder(
        builder: (context) {
          seen = context.fluvie;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return seen;
}

void main() {
  group('FluvieTheme — context.fluvie resolution', () {
    testWidgets('resolves the brand / type / motion under a theme', (tester) async {
      final type = TypeScale.fromBase(18);
      const motion = Defaults(ease: Ease.out);
      final seen = await _tokensVia(
        tester,
        (probe) => FluvieTheme(palette: _brand, type: type, motion: motion, child: probe),
      );
      expect(seen.brand, _brand);
      expect(seen.type, type);
      expect(seen.motion, motion);
    });

    testWidgets('a subtree with no theme reads the fallback', (tester) async {
      final seen = await _tokensVia(tester, (probe) => probe);
      expect(seen, const FluvieTokens.fallback());
      expect(seen.brand, const Palette.fallback());
    });

    testWidgets('omitted arguments keep the nearest (here fallback) values', (tester) async {
      final seen = await _tokensVia(tester, (probe) => FluvieTheme(child: probe));
      expect(seen.brand, const Palette.fallback());
      expect(seen.type, const TypeScale.fallback());
      expect(seen.motion, const Defaults());
    });
  });

  group('FluvieTheme — nesting', () {
    testWidgets('an inner theme overrides an outer one', (tester) async {
      final seen = await _tokensVia(
        tester,
        (probe) => FluvieTheme(
          palette: _other,
          child: FluvieTheme(palette: _brand, child: probe),
        ),
      );
      expect(seen.brand, _brand);
    });

    testWidgets('an inner theme inherits the outer fields it does not set', (tester) async {
      final outerType = TypeScale.fromBase(22);
      final seen = await _tokensVia(
        tester,
        (probe) => FluvieTheme(
          palette: _other,
          type: outerType,
          // The inner theme overrides only the palette; type cascades down.
          child: FluvieTheme(palette: _brand, child: probe),
        ),
      );
      expect(seen.brand, _brand);
      expect(seen.type, outerType);
    });
  });

  group('FluvieTheme — the .brand vs .palette split', () {
    testWidgets('an explicit palette sets only the brand, never the series palette', (
      tester,
    ) async {
      final seen = await _tokensVia(tester, (probe) => FluvieTheme(palette: _brand, child: probe));
      expect(seen.brand, _brand);
      // The chart-series ChartPalette is untouched — still the fallback series.
      expect(seen.palette, const FluvieTokens.fallback().palette);
    });

    testWidgets('the element themes (code / mermaid / captions) stay the nearest values', (
      tester,
    ) async {
      const fallback = FluvieTokens.fallback();
      final seen = await _tokensVia(tester, (probe) => FluvieTheme(palette: _brand, child: probe));
      expect(seen.code, fallback.code);
      expect(seen.mermaid, fallback.mermaid);
      expect(seen.captions, fallback.captions);
      expect(seen.axisColor, fallback.axisColor);
    });
  });
}
