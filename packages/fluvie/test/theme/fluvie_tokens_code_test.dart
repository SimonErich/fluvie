// WI-4 (D-Theme): FluvieTokens grows IN PLACE with a defaulted `code` field. The
// fallback and the main constructor default it to CodeTheme.dark() so existing
// chart call sites compile unchanged; a custom `code:` is carried value-equal;
// `context.fluvie.code` resolves it through the existing scope (no new scope).

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

void main() {
  group('FluvieTokens.code (grown in place)', () {
    test('the fallback defaults code to CodeTheme.dark()', () {
      expect(const FluvieTokens.fallback().code, const CodeTheme.dark());
    });

    test('the main constructor defaults code so existing call sites compile', () {
      const tokens = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
      );
      expect(tokens.code, const CodeTheme.dark());
    });

    test('carries a custom code and stays value-equal', () {
      const a = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
        code: CodeTheme.light(),
      );
      const b = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
        code: CodeTheme.light(),
      );
      expect(a.code, const CodeTheme.light());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const FluvieTokens.fallback()));
    });

    testWidgets('context.fluvie.code resolves through the existing scope', (tester) async {
      late CodeTheme resolved;
      await tester.pumpWidget(
        FluvieTokensScope(
          tokens: const FluvieTokens(
            palette: ChartPalette([Color(0xFF6C5CE7)]),
            axisColor: Color(0xFF9E9E9E),
            gridColor: Color(0x33FFFFFF),
            labelColor: Color(0xFFE0E0E0),
            code: CodeTheme.light(),
          ),
          child: Builder(
            builder: (context) {
              resolved = context.fluvie.code;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, const CodeTheme.light());
    });

    testWidgets('context.fluvie.code falls back to dark with no scope', (tester) async {
      late CodeTheme resolved;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = context.fluvie.code;
            return const SizedBox();
          },
        ),
      );
      expect(resolved, const CodeTheme.dark());
    });
  });
}
