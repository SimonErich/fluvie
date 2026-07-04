import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/connector.dart';
import 'package:fluvie/src/elements/annotations/render/connector_painter.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

import 'annotation_harness.dart';

ConnectorPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Connector), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as ConnectorPainter;
}

void main() {
  group('Connector geometry', () {
    testWidgets('links two explicit points', (tester) async {
      await pumpAnnotation(
        tester,
        const Connector(from: Offset(10, 10), to: Offset(80, 60)),
      );
      final painter = _painter(tester);
      expect(painter.from, const Offset(10, 10));
      expect(painter.to, const Offset(80, 60));
    });

    testWidgets('an elbow connector bends through a mid corner', (tester) async {
      await pumpAnnotation(
        tester,
        const Connector(from: Offset.zero, to: Offset(100, 100), elbow: true),
      );
      final painter = _painter(tester);
      expect(painter.corner, isNotNull);
      // The elbow bends horizontal-first: the corner shares the start's y.
      expect(painter.corner!.dy, 0);
      expect(painter.corner!.dx, 100);
    });

    testWidgets('a straight connector has no corner', (tester) async {
      await pumpAnnotation(
        tester,
        const Connector(from: Offset.zero, to: Offset(100, 100)),
      );
      expect(_painter(tester).corner, isNull);
    });
  });

  group('Connector draw-on', () {
    testWidgets('progress runs 0 -> 1 over the reveal', (tester) async {
      const connector = Connector(
        from: Offset.zero,
        to: Offset(100, 0),
        reveal: Time.frames(20),
      );
      await pumpAnnotation(tester, connector);
      expect(_painter(tester).progress, 0);
      await pumpAnnotation(tester, connector, frame: 10);
      expect(_painter(tester).progress, closeTo(0.5, 1e-9));
      await pumpAnnotation(tester, connector, frame: 20);
      expect(_painter(tester).progress, 1);
    });
  });

  group('Connector theming and contract', () {
    testWidgets('colors from context.fluvie when no color is given', (tester) async {
      const tokens = FluvieTokens.fallback();
      await pumpAnnotation(
        tester,
        const Connector(from: Offset.zero, to: Offset(50, 50)),
        wrap: (child) => FluvieTokensScope(tokens: tokens, child: child),
      );
      expect(_painter(tester).color, tokens.palette.colorAt(0));
    });

    testWidgets('is not a CollectibleChildren (a leaf painter)', (tester) async {
      const connector = Connector(from: Offset.zero, to: Offset(1, 1));
      expect(connector, isNot(isA<CollectibleChildren>()));
    });

    testWidgets('shared wraps the connector in a SharedElement', (tester) async {
      final anchor = Anchor('connector');
      await pumpAnnotation(
        tester,
        Connector(from: Offset.zero, to: const Offset(50, 50), shared: anchor),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });
  });
}
