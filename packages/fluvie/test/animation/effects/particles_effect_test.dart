import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/particles_effect.dart';
import 'package:fluvie/src/animation/effects/particles_painter.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:fluvie/src/core/particles/particles.dart';

const _size = Size(100, 100);
const _black = Color(0xFF000000);
const _probeKey = Key('probe');

const _child = SizedBox(width: 100, height: 100, child: ColoredBox(color: _black));

/// Mounts [built] inside a 100x100 repaint boundary so its pixels read back
/// exactly as a capture would (RepaintBoundary.toImage).
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

/// Counts how many of the boundary's pixels are not the flat black background.
int _painted(ByteData data) {
  var painted = 0;
  for (var i = 0; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) != 0 || data.getUint8(i + 1) != 0 || data.getUint8(i + 2) != 0) {
      painted++;
    }
  }
  return painted;
}

void main() {
  group('ParticlesEffect — classification (D6)', () {
    test('classifies as a pixel post-effect', () {
      const effect = ParticlesEffect(Particles.confetti());
      expect(effectKindOf(effect), EffectKind.pixel);
      expect(effect, isA<PixelAnimationEffect>());
    });

    test('carries its spec', () {
      const spec = Particles.snow(count: 9, seed: 's');
      const effect = ParticlesEffect(spec);
      expect(effect.spec, spec);
    });
  });

  group('ParticlesEffect — build', () {
    testWidgets('wraps the child in a foreground CustomPaint', (tester) async {
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti()).build(_child, 0.5)),
      );
      final paint = tester.widget<CustomPaint>(
        find.ancestor(of: find.byType(ColoredBox), matching: find.byType(CustomPaint)).first,
      );
      expect(paint.foregroundPainter, isNotNull);
      expect(paint.painter, isNull, reason: 'particles overlay the child, never paint behind it');
    });

    testWidgets('draws particles over the child', (tester) async {
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(count: 30)).build(_child, 0.5)),
      );
      expect(_painted(await _bytes(tester)), greaterThan(0), reason: 'particles must paint');
    });

    testWidgets('a higher count paints more than a lower count', (tester) async {
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(count: 4, seed: 'c')).build(_child, 0.5)),
      );
      final few = _painted(await _bytes(tester));
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(count: 40, seed: 'c')).build(_child, 0.5)),
      );
      final many = _painted(await _bytes(tester));
      expect(many, greaterThan(few));
    });
  });

  group('ParticlesEffect — determinism (§22)', () {
    testWidgets('two pumps at the same frame paint identical pixels', (tester) async {
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(seed: 'd')).build(_child, 0.42)),
      );
      final first = await _bytes(tester);
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(seed: 'd')).build(_child, 0.42)),
      );
      final second = await _bytes(tester);
      expect(first.buffer.asUint8List(), second.buffer.asUint8List());
    });

    testWidgets('the same seed lays the same field, a different seed differs', (tester) async {
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(seed: 'a')).build(_child, 0.3)),
      );
      final a1 = await _bytes(tester);
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(seed: 'a')).build(_child, 0.3)),
      );
      final a2 = await _bytes(tester);
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(seed: 'b')).build(_child, 0.3)),
      );
      final b = await _bytes(tester);
      expect(a1.buffer.asUint8List(), a2.buffer.asUint8List());
      expect(a1.buffer.asUint8List(), isNot(b.buffer.asUint8List()));
    });
  });

  group('ParticlesEffect — kinds differ in motion', () {
    testWidgets('confetti and snow at the same frame paint different fields', (tester) async {
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.confetti(seed: 'k', count: 20)).build(_child, 0.5)),
      );
      final confetti = await _bytes(tester);
      await tester.pumpWidget(
        _host(const ParticlesEffect(Particles.snow(seed: 'k', count: 20)).build(_child, 0.5)),
      );
      final snow = await _bytes(tester);
      expect(confetti.buffer.asUint8List(), isNot(snow.buffer.asUint8List()));
    });

    test('particle positions advance with progress (the field moves)', () {
      const effect = ParticlesEffect(Particles.snow(seed: 'm', count: 5));
      final early = effect.placementsAt(0.1, _size);
      final late_ = effect.placementsAt(0.6, _size);
      expect(early.length, 5);
      // Snow falls, so every particle's y is lower (greater) later in the scene.
      for (var i = 0; i < early.length; i++) {
        expect(late_[i].dy, greaterThan(early[i].dy), reason: 'particle $i must fall');
      }
    });
  });

  group('ParticlesEffect — shouldRepaint', () {
    test('repaints only when progress or spec changes', () {
      // The effect's build now wraps the painter in a NoiseScope-reading Builder,
      // so the painter is constructed directly to test its repaint contract.
      const painter = ParticlesPainter(
        spec: Particles.confetti(),
        progress: 0.5,
        noise: ValueNoise(),
      );
      const same = ParticlesPainter(spec: Particles.confetti(), progress: 0.5, noise: ValueNoise());
      const laterFrame = ParticlesPainter(
        spec: Particles.confetti(),
        progress: 0.8,
        noise: ValueNoise(),
      );
      const otherSpec = ParticlesPainter(
        spec: Particles.snow(),
        progress: 0.5,
        noise: ValueNoise(),
      );
      expect(painter.shouldRepaint(same), isFalse);
      expect(painter.shouldRepaint(laterFrame), isTrue);
      expect(painter.shouldRepaint(otherSpec), isTrue);
    });
  });
}
