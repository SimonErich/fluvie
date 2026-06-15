import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';

const _size = Size(80, 80);
const _gray = Color(0xFF808080);
const _probeKey = Key('probe');

const _child = SizedBox(width: 80, height: 80, child: ColoredBox(color: _gray));

/// Mounts [built] inside an 80x80 repaint boundary so its pixels can be read
/// back exactly as a capture would (RepaintBoundary.toImage).
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

void main() {
  group('GrainEffect — classification (D2)', () {
    test('classifies as a pixel post-effect', () {
      expect(effectKindOf(const GrainEffect(0.3)), EffectKind.pixel);
      expect(const GrainEffect(0.3), isA<PixelAnimationEffect>());
    });

    test('clamps amount into [0, 1]', () {
      expect(const GrainEffect(-0.5).amount, 0.0);
      expect(const GrainEffect(2).amount, 1.0);
      expect(const GrainEffect(0.4).amount, 0.4);
    });
  });

  group('GrainEffect — build', () {
    testWidgets('wraps the child in a foreground CustomPaint', (tester) async {
      await tester.pumpWidget(_host(const GrainEffect(0.4).build(_child, 1)));
      final paint = tester.widget<CustomPaint>(
        find.ancestor(of: find.byType(ColoredBox), matching: find.byType(CustomPaint)).first,
      );
      expect(paint.foregroundPainter, isNotNull);
      expect(paint.painter, isNull, reason: 'grain overlays the child, never paints behind it');
    });

    testWidgets('amount 0 leaves the child untouched (no speckle)', (tester) async {
      await tester.pumpWidget(_host(const GrainEffect(0).build(_child, 1)));
      final data = await _bytes(tester);
      // Every pixel stays the flat gray: nothing was drawn over it.
      for (var i = 0; i < data.lengthInBytes; i += 4) {
        expect(data.getUint8(i), 0x80);
      }
    });

    testWidgets('a positive amount actually paints speckle over the child', (tester) async {
      await tester.pumpWidget(_host(const GrainEffect(0.8).build(_child, 1)));
      final data = await _bytes(tester);
      var altered = 0;
      for (var i = 0; i < data.lengthInBytes; i += 4) {
        if (data.getUint8(i) != 0x80) altered++;
      }
      expect(altered, greaterThan(0), reason: 'grain must perturb some pixels');
    });
  });

  group('GrainEffect — determinism (§22)', () {
    testWidgets('two pumps at the same frame paint identical pixels', (tester) async {
      await tester.pumpWidget(_host(const GrainEffect(0.6).build(_child, 0.5)));
      final first = await _bytes(tester);
      await tester.pumpWidget(_host(const GrainEffect(0.6).build(_child, 0.5)));
      final second = await _bytes(tester);
      expect(first.buffer.asUint8List(), second.buffer.asUint8List());
    });
  });

  group('GrainEffect — shouldRepaint', () {
    /// The foreground painter the effect mounts at [amount]/[progress] — the
    /// build now wraps it in a NoiseScope-reading Builder, so it is read back
    /// from the pumped tree rather than cast directly.
    Future<CustomPainter> painterOf(WidgetTester tester, double amount, double progress) async {
      await tester.pumpWidget(_host(GrainEffect(amount).build(_child, progress)));
      final paint = tester.widget<CustomPaint>(
        find.ancestor(of: find.byType(ColoredBox), matching: find.byType(CustomPaint)).first,
      );
      return paint.foregroundPainter!;
    }

    testWidgets('repaints only when progress or amount changes', (tester) async {
      final painter = await painterOf(tester, 0.4, 0.5);
      final samePaint = await painterOf(tester, 0.4, 0.5);
      final sameAmount = await painterOf(tester, 0.4, 0.8);
      final otherAmount = await painterOf(tester, 0.9, 0.5);
      expect(painter.shouldRepaint(samePaint), isFalse);
      expect(painter.shouldRepaint(sameAmount), isTrue);
      expect(painter.shouldRepaint(otherAmount), isTrue);
    });
  });
}
