// Epic 10.4 (WI-13, D11): the FluvieTokensScope + the `context.fluvie` accessor.
// The scope carries FluvieTokens down the tree; `of` returns the nearest tokens
// or the const fallback when absent (never throws — tokens are optional, unlike
// the frame clock). The `context.fluvie` extension resolves the same tokens.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

/// A branded tokens value used to prove the scope shadows the fallback.
const _brand = FluvieTokens(
  palette: ChartPalette([Color(0xFFFF0000), Color(0xFF00FF00)]),
  axisColor: Color(0xFF111111),
  gridColor: Color(0xFF222222),
  labelColor: Color(0xFF333333),
);

const _other = FluvieTokens(
  palette: ChartPalette([Color(0xFF0000FF)]),
  axisColor: Color(0xFF444444),
  gridColor: Color(0xFF555555),
  labelColor: Color(0xFF666666),
);

/// Mounts a probe inside [wrap] and captures the [FluvieTokens] visible at its
/// context via the given [read] accessor.
Future<FluvieTokens> _tokensVia(
  WidgetTester tester,
  Widget Function(Widget probe) wrap,
  FluvieTokens Function(BuildContext) read,
) async {
  late FluvieTokens seen;
  await tester.pumpWidget(
    wrap(
      Builder(
        builder: (context) {
          seen = read(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return seen;
}

void main() {
  group('FluvieTokensScope.of', () {
    testWidgets('returns the nearest tokens when a scope is present', (tester) async {
      final seen = await _tokensVia(
        tester,
        (probe) => FluvieTokensScope(tokens: _brand, child: probe),
        FluvieTokensScope.of,
      );
      expect(seen, _brand);
    });

    testWidgets('returns the const fallback when no scope is present (never throws)', (
      tester,
    ) async {
      final seen = await _tokensVia(tester, (probe) => probe, FluvieTokensScope.of);
      expect(seen, const FluvieTokens.fallback());
    });

    testWidgets('the nearest (inner) scope shadows an outer one', (tester) async {
      final seen = await _tokensVia(
        tester,
        (probe) => FluvieTokensScope(
          tokens: _other,
          child: FluvieTokensScope(tokens: _brand, child: probe),
        ),
        FluvieTokensScope.of,
      );
      expect(seen, _brand);
    });
  });

  group('context.fluvie', () {
    testWidgets('resolves through the extension to the nearest tokens', (tester) async {
      final seen = await _tokensVia(
        tester,
        (probe) => FluvieTokensScope(tokens: _brand, child: probe),
        (context) => context.fluvie,
      );
      expect(seen, _brand);
    });

    testWidgets('returns the fallback with no scope', (tester) async {
      final seen = await _tokensVia(tester, (probe) => probe, (context) => context.fluvie);
      expect(seen, const FluvieTokens.fallback());
    });

    testWidgets('exposes the caption theme through context.fluvie.captions', (tester) async {
      final seen = await _tokensVia(tester, (probe) => probe, (context) => context.fluvie);
      expect(seen.captions, isNotNull);
    });

    testWidgets('exposes the §21 brand / type / motion through context.fluvie', (tester) async {
      final seen = await _tokensVia(tester, (probe) => probe, (context) => context.fluvie);
      expect(seen.brand, isNotNull);
      expect(seen.type, isNotNull);
      expect(seen.motion, isNotNull);
    });
  });

  group('FluvieTokensScope.updateShouldNotify', () {
    test('notifies only when the tokens change', () {
      const a = FluvieTokensScope(tokens: _brand, child: SizedBox.shrink());
      const b = FluvieTokensScope(tokens: _other, child: SizedBox.shrink());
      const same = FluvieTokensScope(tokens: _brand, child: SizedBox.shrink());
      expect(a.updateShouldNotify(b), isTrue);
      expect(a.updateShouldNotify(same), isFalse);
    });
  });
}
