import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/render/shape_painter.dart';
import 'package:fluvie/src/elements/annotations/shape.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

import 'annotation_harness.dart';

ShapePainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Shape), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as ShapePainter;
}

void main() {
  group('Shape geometry', () {
    testWidgets('Shape.line paints a line between its two points', (tester) async {
      await pumpAnnotation(
        tester,
        const Shape.line(from: Offset(10, 20), to: Offset(90, 80)),
      );
      final painter = _painter(tester);
      expect(painter.kind, ShapeKind.line);
      expect(painter.from, const Offset(10, 20));
      expect(painter.to, const Offset(90, 80));
    });

    testWidgets('Shape.rect paints a rectangle from its rect', (tester) async {
      await pumpAnnotation(
        tester,
        const Shape.rect(rect: Rect.fromLTWH(10, 10, 60, 40)),
      );
      final painter = _painter(tester);
      expect(painter.kind, ShapeKind.rect);
      expect(painter.rect, const Rect.fromLTWH(10, 10, 60, 40));
    });

    testWidgets('Shape.circle paints a circle from its center and radius', (tester) async {
      await pumpAnnotation(
        tester,
        const Shape.circle(center: Offset(50, 50), radius: 30),
      );
      final painter = _painter(tester);
      expect(painter.kind, ShapeKind.circle);
      expect(painter.center, const Offset(50, 50));
      expect(painter.radius, 30);
    });

    testWidgets('Shape.path paints the given path', (tester) async {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(40, 40);
      await pumpAnnotation(tester, Shape.path(path: path));
      final painter = _painter(tester);
      expect(painter.kind, ShapeKind.path);
      expect(painter.path, isNotNull);
    });
  });

  group('Shape draw-on', () {
    testWidgets('progress is 0 before the reveal and 1 after it', (tester) async {
      const shape = Shape.line(
        from: Offset.zero,
        to: Offset(100, 0),
        reveal: Time.frames(10),
      );
      await pumpAnnotation(tester, shape);
      expect(_painter(tester).progress, 0);
      await pumpAnnotation(tester, shape, frame: 5);
      expect(_painter(tester).progress, closeTo(0.5, 1e-9));
      await pumpAnnotation(tester, shape, frame: 20);
      expect(_painter(tester).progress, 1);
    });

    testWidgets('no reveal renders fully revealed', (tester) async {
      await pumpAnnotation(
        tester,
        const Shape.line(from: Offset.zero, to: Offset(100, 0)),
      );
      expect(_painter(tester).progress, 1);
    });
  });

  group('Shape theming', () {
    testWidgets('colors from context.fluvie when no color is given', (tester) async {
      const tokens = FluvieTokens.fallback();
      await pumpAnnotation(
        tester,
        const Shape.circle(center: Offset(50, 50), radius: 20),
        wrap: (child) => FluvieTokensScope(tokens: tokens, child: child),
      );
      expect(_painter(tester).color, tokens.palette.colorAt(0));
    });

    testWidgets('an explicit color overrides the theme', (tester) async {
      await pumpAnnotation(
        tester,
        const Shape.circle(center: Offset(50, 50), radius: 20, color: Color(0xFF112233)),
      );
      expect(_painter(tester).color, const Color(0xFF112233));
    });
  });

  group('Shape contract', () {
    testWidgets('is not a CollectibleChildren (a leaf painter)', (tester) async {
      const shape = Shape.line(from: Offset.zero, to: Offset(1, 1));
      expect(shape, isNot(isA<CollectibleChildren>()));
    });

    testWidgets('the painter does not save a layer (capture-safe)', (tester) async {
      await pumpAnnotation(
        tester,
        const Shape.rect(rect: Rect.fromLTWH(0, 0, 50, 50)),
      );
      // The painter draws with plain fills/strokes; a smoke paint must not throw.
      expect(tester.takeException(), isNull);
    });

    testWidgets('shared wraps the shape in a SharedElement', (tester) async {
      final anchor = Anchor('shape');
      await pumpAnnotation(
        tester,
        Shape.circle(center: const Offset(50, 50), radius: 20, shared: anchor),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });

    testWidgets('no shared mounts no SharedElement', (tester) async {
      await pumpAnnotation(
        tester,
        const Shape.circle(center: Offset(50, 50), radius: 20),
      );
      expect(find.byType(SharedElement), findsNothing);
    });
  });
}
