import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/bloom_effect.dart';

const _size = Size(80, 80);
const _probeKey = Key('probe');

// A small bright square on black, so a bloom glow bleeds light into the
// surrounding dark pixels.
const _child = SizedBox(
  width: 24,
  height: 24,
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

int _lumaAt(ByteData data, int width, int x, int y) => data.getUint8((y * width + x) * 4);

void main() {
  group('BloomEffect — classification (D2)', () {
    test('classifies as a pixel post-effect', () {
      expect(effectKindOf(const BloomEffect(0.5)), EffectKind.pixel);
      expect(const BloomEffect(0.5), isA<PixelAnimationEffect>());
    });

    test('clamps amount into [0, 1]', () {
      expect(const BloomEffect(-1).amount, 0.0);
      expect(const BloomEffect(3).amount, 1.0);
      expect(const BloomEffect(0.5).amount, 0.5);
    });
  });

  group('BloomEffect — build', () {
    testWidgets('uses ImageFiltered (a render-object blur, capture-safe), no BackdropFilter', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const BloomEffect(0.8).build(_child, 1)));
      expect(find.byType(ImageFiltered), findsWidgets);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('bleeds light into the dark margin around the bright square', (tester) async {
      // Without bloom the pixels just outside the 24px square are pure black.
      await tester.pumpWidget(_host(const BloomEffect(0).build(_child, 1)));
      final plain = _lumaAt(await _bytes(tester), 80, 22, 40);
      expect(plain, 0, reason: 'no bloom: the margin stays black');

      await tester.pumpWidget(_host(const BloomEffect(0.9).build(_child, 1)));
      final bloomed = _lumaAt(await _bytes(tester), 80, 22, 40);
      expect(bloomed, greaterThan(plain), reason: 'bloom must lift the surrounding dark pixels');
    });
  });

  group('BloomEffect — determinism (§22)', () {
    testWidgets('two pumps paint identical pixels', (tester) async {
      await tester.pumpWidget(_host(const BloomEffect(0.7).build(_child, 1)));
      final first = await _bytes(tester);
      await tester.pumpWidget(_host(const BloomEffect(0.7).build(_child, 1)));
      expect(first.buffer.asUint8List(), (await _bytes(tester)).buffer.asUint8List());
    });
  });
}
