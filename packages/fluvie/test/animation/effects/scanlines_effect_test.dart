import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/scanlines_effect.dart';

const _size = Size(80, 80);
const _white = Color(0xFFFFFFFF);
const _probeKey = Key('probe');

const _child = SizedBox(width: 80, height: 80, child: ColoredBox(color: _white));

Widget _host(Widget built) => Center(
  child: RepaintBoundary(
    key: _probeKey,
    child: SizedBox(width: _size.width, height: _size.height, child: built),
  ),
);

Future<ByteData> _bytes(WidgetTester tester) async {
  final boundary = tester.renderObject(find.byKey(_probeKey)) as RenderRepaintBoundary;
  late final ByteData data;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    data = (await image.toByteData())!;
    image.dispose();
  });
  return data;
}

int _lumaAt(ByteData data, int width, int x, int y) => data.getUint8((y * width + x) * 4);

void main() {
  group('ScanlinesEffect — classification (D2)', () {
    test('classifies as a pixel post-effect', () {
      expect(effectKindOf(const ScanlinesEffect()), EffectKind.pixel);
      expect(const ScanlinesEffect(), isA<PixelAnimationEffect>());
    });

    test('takes no required parameter and carries a default spacing and opacity', () {
      const effect = ScanlinesEffect();
      expect(effect.spacing, greaterThan(0));
      expect(effect.opacity, inInclusiveRange(0, 1));
    });
  });

  group('ScanlinesEffect — build', () {
    testWidgets('wraps the child in a foreground CustomPaint', (tester) async {
      await tester.pumpWidget(_host(const ScanlinesEffect().build(_child, 1)));
      final paint = tester.widget<CustomPaint>(
        find.ancestor(of: find.byType(ColoredBox), matching: find.byType(CustomPaint)).first,
      );
      expect(paint.foregroundPainter, isNotNull);
      expect(paint.painter, isNull);
    });

    testWidgets('darkens periodic rows, leaving the rows between them bright', (tester) async {
      await tester.pumpWidget(_host(const ScanlinesEffect(spacing: 4).build(_child, 1)));
      final data = await _bytes(tester);
      // A 4px spacing draws a dark line every 4 rows; the mid rows stay white.
      expect(_lumaAt(data, 80, 40, 0), lessThan(0xFF), reason: 'a scanline row is darkened');
      expect(_lumaAt(data, 80, 40, 2), 0xFF, reason: 'the gap between scanlines stays bright');
    });
  });

  group('ScanlinesEffect — determinism (§22)', () {
    testWidgets('two pumps paint identical pixels', (tester) async {
      await tester.pumpWidget(_host(const ScanlinesEffect().build(_child, 1)));
      final first = await _bytes(tester);
      await tester.pumpWidget(_host(const ScanlinesEffect().build(_child, 1)));
      expect(first.buffer.asUint8List(), (await _bytes(tester)).buffer.asUint8List());
    });
  });

  group('ScanlinesEffect — shouldRepaint', () {
    test('repaints only when spacing, opacity, or progress changes', () {
      final painter =
          (const ScanlinesEffect().build(_child, 0.5) as CustomPaint).foregroundPainter!;
      final same = (const ScanlinesEffect().build(_child, 0.5) as CustomPaint).foregroundPainter!;
      final other =
          (const ScanlinesEffect(spacing: 6).build(_child, 0.5) as CustomPaint).foregroundPainter!;
      expect(painter.shouldRepaint(same), isFalse);
      expect(painter.shouldRepaint(other), isTrue);
    });
  });
}
