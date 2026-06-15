import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/chromatic_effect.dart';

const _size = Size(80, 80);
const _probeKey = Key('probe');

// A white square on black so an RGB split shows colored fringes at the edges.
const _child = SizedBox(
  width: 40,
  height: 40,
  child: ColoredBox(color: Color(0xFFFFFFFF)),
);

Widget _host(Widget built) => Center(
  child: RepaintBoundary(
    key: _probeKey,
    child: SizedBox(
      width: _size.width,
      height: _size.height,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: Center(child: built),
      ),
    ),
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

({int r, int g, int b}) _rgbAt(ByteData data, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return (r: data.getUint8(i), g: data.getUint8(i + 1), b: data.getUint8(i + 2));
}

void main() {
  group('ChromaticEffect — classification (D2)', () {
    test('classifies as a pixel post-effect', () {
      expect(effectKindOf(const ChromaticEffect(2)), EffectKind.pixel);
      expect(const ChromaticEffect(2), isA<PixelAnimationEffect>());
    });

    test('carries its split distance in logical pixels', () {
      expect(const ChromaticEffect(3).px, 3);
    });
  });

  group('ChromaticEffect — build', () {
    testWidgets('splits color channels at the edges (a colored fringe appears)', (tester) async {
      await tester.pumpWidget(_host(const ChromaticEffect(4).build(_child, 1)));
      final data = await _bytes(tester);
      // Just left of the white square's left edge: the red channel shifted left
      // leaks here while green/blue do not, so the pixel is not neutral gray.
      var foundFringe = false;
      for (var y = 30; y < 50; y++) {
        for (var x = 14; x < 22; x++) {
          final px = _rgbAt(data, 80, x, y);
          if ((px.r - px.b).abs() > 30 || (px.r - px.g).abs() > 30) foundFringe = true;
        }
      }
      expect(foundFringe, isTrue, reason: 'an RGB split must leave a colored fringe');
    });
  });

  group('ChromaticEffect — determinism (§22)', () {
    testWidgets('two pumps paint identical pixels', (tester) async {
      await tester.pumpWidget(_host(const ChromaticEffect(4).build(_child, 1)));
      final first = await _bytes(tester);
      await tester.pumpWidget(_host(const ChromaticEffect(4).build(_child, 1)));
      expect(first.buffer.asUint8List(), (await _bytes(tester)).buffer.asUint8List());
    });
  });
}
