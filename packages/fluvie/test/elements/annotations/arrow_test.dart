import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/arrow.dart';
import 'package:fluvie/src/elements/annotations/render/arrow_painter.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

import 'annotation_harness.dart';

ArrowPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Arrow), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as ArrowPainter;
}

void main() {
  group('Arrow geometry', () {
    testWidgets('Arrow.to carries its head and shaft endpoints', (tester) async {
      await pumpAnnotation(
        tester,
        const Arrow.to(from: Offset(10, 10), to: Offset(90, 10)),
      );
      final painter = _painter(tester);
      expect(painter.from, const Offset(10, 10));
      expect(painter.to, const Offset(90, 10));
      expect(painter.headLength, greaterThan(0));
    });

    testWidgets('the shaft end at progress p sits p of the way to the head base', (tester) async {
      const arrow = Arrow.to(from: Offset.zero, to: Offset(100, 0));
      // The head base is set back from the tip by headLength; the shaft draws
      // from `from` to that base, clipped to progress.
      final painter = ArrowPainter(
        from: Offset.zero,
        to: const Offset(100, 0),
        color: const Color(0xFF000000),
        progress: 0.5,
        strokeWidth: 3,
        headLength: 12,
      );
      final base = painter.headBase;
      final shaftEnd = painter.shaftEnd;
      expect(shaftEnd.dx, closeTo(base.dx * 0.5, 1e-6));
      expect(arrow, isA<Arrow>());
    });
  });

  group('Arrow draw-on', () {
    testWidgets('the shaft is clipped 0 -> 1 over the reveal', (tester) async {
      const arrow = Arrow.to(
        from: Offset(0, 50),
        to: Offset(100, 50),
        drawIn: Time.frames(10),
      );
      await pumpAnnotation(tester, arrow);
      expect(_painter(tester).progress, 0);
      await pumpAnnotation(tester, arrow, frame: 5);
      expect(_painter(tester).progress, closeTo(0.5, 1e-9));
      await pumpAnnotation(tester, arrow, frame: 10);
      expect(_painter(tester).progress, 1);
    });

    testWidgets('the head only appears once the shaft has drawn fully', (tester) async {
      final mid = ArrowPainter(
        from: Offset.zero,
        to: const Offset(100, 0),
        color: const Color(0xFF000000),
        progress: 0.5,
        strokeWidth: 3,
        headLength: 12,
      );
      final done = ArrowPainter(
        from: Offset.zero,
        to: const Offset(100, 0),
        color: const Color(0xFF000000),
        progress: 1,
        strokeWidth: 3,
        headLength: 12,
      );
      expect(mid.headVisible, isFalse);
      expect(done.headVisible, isTrue);
    });

    testWidgets('no drawIn renders fully (head visible at frame 0)', (tester) async {
      await pumpAnnotation(
        tester,
        const Arrow.to(from: Offset.zero, to: Offset(100, 0)),
      );
      expect(_painter(tester).progress, 1);
      expect(_painter(tester).headVisible, isTrue);
    });
  });

  group('Arrow theming and contract', () {
    testWidgets('colors from context.fluvie when no color is given', (tester) async {
      const tokens = FluvieTokens.fallback();
      await pumpAnnotation(
        tester,
        const Arrow.to(from: Offset.zero, to: Offset(50, 50)),
        wrap: (child) => FluvieTokensScope(tokens: tokens, child: child),
      );
      expect(_painter(tester).color, tokens.palette.colorAt(0));
    });

    testWidgets('is not a CollectibleChildren (a leaf painter)', (tester) async {
      const arrow = Arrow.to(from: Offset.zero, to: Offset(1, 1));
      expect(arrow, isNot(isA<CollectibleChildren>()));
    });

    testWidgets('shared wraps the arrow in a SharedElement', (tester) async {
      final anchor = Anchor('arrow');
      await pumpAnnotation(
        tester,
        Arrow.to(from: Offset.zero, to: const Offset(50, 50), shared: anchor),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });
  });
}
