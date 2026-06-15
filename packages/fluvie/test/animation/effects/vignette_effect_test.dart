import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/vignette_effect.dart';

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

Future<int> _luma(WidgetTester tester, int x, int y) async {
  final boundary = tester.renderObject(find.byKey(_probeKey)) as RenderRepaintBoundary;
  late final ByteData data;
  late final int width;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    width = image.width;
    data = (await image.toByteData())!;
    image.dispose();
  });
  return data.getUint8((y * width + x) * 4);
}

void main() {
  group('VignetteEffect — classification (D2)', () {
    test('classifies as a pixel post-effect', () {
      expect(effectKindOf(const VignetteEffect(0.5)), EffectKind.pixel);
      expect(const VignetteEffect(0.5), isA<PixelAnimationEffect>());
    });

    test('clamps amount into [0, 1]', () {
      expect(const VignetteEffect(-1).amount, 0.0);
      expect(const VignetteEffect(5).amount, 1.0);
      expect(const VignetteEffect(0.4).amount, 0.4);
    });
  });

  group('VignetteEffect — build', () {
    testWidgets('wraps the child in a foreground CustomPaint (no saveLayer host)', (tester) async {
      await tester.pumpWidget(_host(const VignetteEffect(0.6).build(_child, 1)));
      final paint = tester.widget<CustomPaint>(
        find.ancestor(of: find.byType(ColoredBox), matching: find.byType(CustomPaint)).first,
      );
      expect(paint.foregroundPainter, isNotNull);
      expect(paint.painter, isNull);
    });

    testWidgets('darkens the corners more than the center', (tester) async {
      await tester.pumpWidget(_host(const VignetteEffect(0.8).build(_child, 1)));
      final center = await _luma(tester, 40, 40);
      final corner = await _luma(tester, 2, 2);
      expect(corner, lessThan(center), reason: 'a vignette darkens edges, not the middle');
      expect(center, greaterThan(200), reason: 'the bright center stays near white');
    });

    testWidgets('amount 0 leaves the child untouched', (tester) async {
      await tester.pumpWidget(_host(const VignetteEffect(0).build(_child, 1)));
      expect(await _luma(tester, 2, 2), 0xFF);
      expect(await _luma(tester, 40, 40), 0xFF);
    });
  });

  group('VignetteEffect — determinism (§22)', () {
    testWidgets('two pumps at the same frame paint identical corners', (tester) async {
      await tester.pumpWidget(_host(const VignetteEffect(0.7).build(_child, 1)));
      final first = await _luma(tester, 4, 4);
      await tester.pumpWidget(_host(const VignetteEffect(0.7).build(_child, 1)));
      expect(await _luma(tester, 4, 4), first);
    });
  });

  group('VignetteEffect — shouldRepaint', () {
    test('repaints only when amount or progress changes', () {
      final painter =
          (const VignetteEffect(0.4).build(_child, 0.5) as CustomPaint).foregroundPainter!;
      final same = (const VignetteEffect(0.4).build(_child, 0.5) as CustomPaint).foregroundPainter!;
      final other =
          (const VignetteEffect(0.9).build(_child, 0.5) as CustomPaint).foregroundPainter!;
      expect(painter.shouldRepaint(same), isFalse);
      expect(painter.shouldRepaint(other), isTrue);
    });
  });
}
