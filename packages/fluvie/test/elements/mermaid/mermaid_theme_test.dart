// WI-9 (D-MermaidTheme): the MermaidTheme value type + FluvieTokens grows IN
// PLACE with a defaulted `mermaid` field. The presets are const + value-equal;
// the fallback and the main constructor default mermaid so existing call sites
// compile unchanged; `context.fluvie.mermaid` resolves through the existing
// scope; a `theme:` override differs from the token default by its cache key.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

void main() {
  group('MermaidTheme presets', () {
    test('dark is const-constructible and value-equal', () {
      const a = MermaidTheme.dark();
      const b = MermaidTheme.dark();
      expect(identical(a, b), isTrue);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('light is const-constructible and value-equal', () {
      const a = MermaidTheme.light();
      const b = MermaidTheme.light();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('dark and light differ', () {
      expect(const MermaidTheme.dark(), isNot(const MermaidTheme.light()));
      expect(const MermaidTheme.dark().cacheKey, isNot(const MermaidTheme.light().cacheKey));
    });

    test('presets carry a mermaid variant and theme variables', () {
      const dark = MermaidTheme.dark();
      expect(dark.variant, isNotEmpty);
      expect(dark.themeVariables, isNotEmpty);
    });

    test('a custom theme is value-equal by its variant and variables', () {
      const a = MermaidTheme(variant: 'base', themeVariables: {'primaryColor': '#ff0000'});
      const b = MermaidTheme(variant: 'base', themeVariables: {'primaryColor': '#ff0000'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.cacheKey, b.cacheKey);
    });

    test('a different variable changes the cache key', () {
      const a = MermaidTheme(variant: 'base', themeVariables: {'primaryColor': '#ff0000'});
      const b = MermaidTheme(variant: 'base', themeVariables: {'primaryColor': '#00ff00'});
      expect(a, isNot(b));
      expect(a.cacheKey, isNot(b.cacheKey));
    });

    test('the cache key is order-independent over the variables', () {
      const a = MermaidTheme(
        variant: 'base',
        themeVariables: {'a': '1', 'b': '2'},
      );
      const b = MermaidTheme(
        variant: 'base',
        themeVariables: {'b': '2', 'a': '1'},
      );
      expect(a.cacheKey, b.cacheKey);
      expect(a, b);
    });

    test('toString names the type and variant', () {
      expect(const MermaidTheme.dark().toString(), contains('MermaidTheme'));
    });
  });

  group('FluvieTokens.mermaid (grown in place)', () {
    test('the fallback defaults mermaid to a non-null theme', () {
      expect(const FluvieTokens.fallback().mermaid, isNotNull);
      expect(const FluvieTokens.fallback().mermaid, isA<MermaidTheme>());
    });

    test('the main constructor defaults mermaid so existing call sites compile', () {
      const tokens = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
      );
      expect(tokens.mermaid, isA<MermaidTheme>());
      expect(tokens.mermaid, const FluvieTokens.fallback().mermaid);
    });

    test('carries a custom mermaid and stays value-equal', () {
      const a = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
        mermaid: MermaidTheme.light(),
      );
      const b = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
        mermaid: MermaidTheme.light(),
      );
      expect(a.mermaid, const MermaidTheme.light());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const FluvieTokens.fallback()));
    });

    testWidgets('context.fluvie.mermaid resolves through the existing scope', (tester) async {
      late MermaidTheme resolved;
      await tester.pumpWidget(
        FluvieTokensScope(
          tokens: const FluvieTokens(
            palette: ChartPalette([Color(0xFF6C5CE7)]),
            axisColor: Color(0xFF9E9E9E),
            gridColor: Color(0x33FFFFFF),
            labelColor: Color(0xFFE0E0E0),
            mermaid: MermaidTheme.light(),
          ),
          child: Builder(
            builder: (context) {
              resolved = context.fluvie.mermaid;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, const MermaidTheme.light());
    });

    testWidgets('context.fluvie.mermaid falls back with no scope', (tester) async {
      late MermaidTheme resolved;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = context.fluvie.mermaid;
            return const SizedBox();
          },
        ),
      );
      expect(resolved, const FluvieTokens.fallback().mermaid);
    });

    test('an explicit theme override differs from the token default', () {
      const def = FluvieTokens.fallback();
      const override = MermaidTheme.light();
      expect(override, isNot(def.mermaid));
      expect(override.cacheKey, isNot(def.mermaid.cacheKey));
    });
  });
}
