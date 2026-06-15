import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/glitch_effect.dart';
import 'package:fluvie/src/core/edge.dart';

const _size = Size(80, 80);
const _probeKey = Key('probe');

const _child = SizedBox(
  width: 60,
  height: 60,
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

void main() {
  group('GlitchEffect — classification (D5)', () {
    test('classifies as a pixel post-effect', () {
      expect(effectKindOf(const GlitchEffect()), EffectKind.pixel);
      expect(const GlitchEffect(), isA<PixelAnimationEffect>());
    });

    test('defaults the slice direction to Edge.left and carries from', () {
      expect(const GlitchEffect().from, Edge.left);
      expect(const GlitchEffect(from: Edge.right).from, Edge.right);
    });
  });

  group('GlitchEffect — resolves to natural', () {
    testWidgets('progress 1 returns the child untouched (no overlay, no slices)', (tester) async {
      const effect = GlitchEffect();
      expect(effect.build(_child, 1), same(_child));
    });

    test('a spring overshoot past 1 also stays natural', () {
      expect(const GlitchEffect().build(_child, 1.3), same(_child));
    });

    testWidgets('mid-progress disturbs the frame (it is not yet natural)', (tester) async {
      await tester.pumpWidget(_host(const GlitchEffect().build(_child, 1)));
      final settled = await _bytes(tester);
      await tester.pumpWidget(_host(const GlitchEffect().build(_child, 0.3)));
      final glitched = await _bytes(tester);
      expect(
        glitched.buffer.asUint8List(),
        isNot(settled.buffer.asUint8List()),
        reason: 'a glitch in flight must differ from the settled frame',
      );
    });
  });

  group('GlitchEffect — determinism (§22)', () {
    testWidgets('same seed and progress paint identical pixels', (tester) async {
      await tester.pumpWidget(_host(const GlitchEffect().build(_child, 0.4)));
      final first = await _bytes(tester);
      await tester.pumpWidget(_host(const GlitchEffect().build(_child, 0.4)));
      expect(first.buffer.asUint8List(), (await _bytes(tester)).buffer.asUint8List());
    });

    testWidgets('opposite from edges jitter the slices differently', (tester) async {
      // The default from is Edge.left; contrast it with an explicit Edge.right.
      await tester.pumpWidget(_host(const GlitchEffect().build(_child, 0.4)));
      final left = await _bytes(tester);
      await tester.pumpWidget(_host(const GlitchEffect(from: Edge.right).build(_child, 0.4)));
      expect(
        (await _bytes(tester)).buffer.asUint8List(),
        isNot(left.buffer.asUint8List()),
        reason: 'the from edge must seed the slice direction',
      );
    });
  });
}
