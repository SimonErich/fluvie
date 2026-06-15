import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/mask_wipe_effect.dart';
import 'package:fluvie/src/core/wipe_shape.dart';

const _size = Size(100, 100);
const _red = Color(0xFFFF0000);
const _white = Color(0xFFFFFFFF);
const _probeKey = Key('probe');

const _child = SizedBox(width: 100, height: 100, child: ColoredBox(color: _red));

/// Mounts [wiped] over a white background inside a 100×100 repaint boundary.
Widget _host(Widget wiped) => Center(
  child: RepaintBoundary(
    key: _probeKey,
    child: SizedBox(
      width: _size.width,
      height: _size.height,
      child: ColoredBox(color: _white, child: wiped),
    ),
  ),
);

/// Reads the rendered pixel at logical ([x], [y]) inside the probe boundary.
Future<Color> _pixelAt(WidgetTester tester, int x, int y) async {
  final boundary = tester.renderObject(find.byKey(_probeKey)) as RenderRepaintBoundary;
  late final ByteData data;
  late final int width;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    width = image.width;
    data = (await image.toByteData())!;
    image.dispose();
  });
  final offset = (y * width + x) * 4;
  return Color.fromARGB(
    data.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
}

/// The clip path the effect mounts at [progress], or `null` when it mounts
/// no clip at all (fully revealed).
Path? _clipAt(MaskWipeEffect effect, double progress) {
  final built = effect.build(_child, progress);
  if (built is! ClipPath) return null;
  return built.clipper!.getClip(_size);
}

void main() {
  group('MaskWipeEffect — classification (D2)', () {
    test('classifies as a transform-class effect, not a pixel effect', () {
      const effect = MaskWipeEffect();
      expect(effectKindOf(effect), EffectKind.transform);
      expect(effect, isNot(isA<PixelAnimationEffect>()));
    });

    test('carries its shape and origin and defaults to circle from center', () {
      const effect = MaskWipeEffect();
      expect(effect.shape, WipeShape.circle);
      expect(effect.origin, Alignment.center);
      const custom = MaskWipeEffect(shape: WipeShape.rect, origin: Alignment.topLeft);
      expect(custom.shape, WipeShape.rect);
      expect(custom.origin, Alignment.topLeft);
    });
  });

  group('MaskWipeEffect — boundary progress', () {
    testWidgets('progress 0 hides every pixel (pixel probe)', (tester) async {
      await tester.pumpWidget(_host(const MaskWipeEffect().build(_child, 0)));
      expect(await _pixelAt(tester, 50, 50), _white);
      expect(await _pixelAt(tester, 5, 5), _white);
      expect(await _pixelAt(tester, 95, 95), _white);
    });

    testWidgets('progress 1 reveals every pixel (pixel probe, no clip mounted)', (tester) async {
      const effect = MaskWipeEffect();
      expect(effect.build(_child, 1), same(_child));
      await tester.pumpWidget(_host(effect.build(_child, 1)));
      expect(find.byType(ClipPath), findsNothing);
      expect(await _pixelAt(tester, 50, 50), _red);
      expect(await _pixelAt(tester, 5, 5), _red);
      expect(await _pixelAt(tester, 95, 95), _red);
    });

    test('spring overshoot past 1 stays fully revealed', () {
      expect(const MaskWipeEffect().build(_child, 1.2), same(_child));
    });
  });

  group('MaskWipeEffect — circle', () {
    test('half progress from center reveals the middle but not the corners', () {
      final path = _clipAt(const MaskWipeEffect(), 0.5)!;
      // Far-corner distance is √(50² + 50²) ≈ 70.71, so the radius is ≈ 35.36.
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(50, 80)), isTrue); // distance 30
      expect(path.contains(const Offset(50, 10)), isFalse); // distance 40
      expect(path.contains(const Offset(10, 50)), isFalse); // distance 40
      for (final corner in const [Offset(1, 1), Offset(99, 1), Offset(1, 99), Offset(99, 99)]) {
        expect(path.contains(corner), isFalse, reason: 'corner $corner must stay hidden');
      }
    });

    testWidgets('half progress pixel probe: center painted, corner background', (tester) async {
      await tester.pumpWidget(_host(const MaskWipeEffect().build(_child, 0.5)));
      expect(await _pixelAt(tester, 50, 50), _red);
      expect(await _pixelAt(tester, 3, 3), _white);
    });

    test('a topLeft origin must reach the far corner at progress 1', () {
      const effect = MaskWipeEffect(origin: Alignment.topLeft);
      final path = _clipAt(effect, 0.5)!;
      // Radius is half of √(100² + 100²) ≈ 70.71 from (0, 0).
      expect(path.contains(const Offset(40, 40)), isTrue); // distance ≈ 56.6
      expect(path.contains(const Offset(60, 60)), isFalse); // distance ≈ 84.9
    });
  });

  group('MaskWipeEffect — rect', () {
    test('honors a topLeft origin: grows right and down only', () {
      const effect = MaskWipeEffect(shape: WipeShape.rect, origin: Alignment.topLeft);
      final path = _clipAt(effect, 0.5)!;
      expect(path.contains(const Offset(25, 25)), isTrue);
      expect(path.contains(const Offset(75, 25)), isFalse);
      expect(path.contains(const Offset(25, 75)), isFalse);
      expect(path.contains(const Offset(75, 75)), isFalse);
    });

    test('grows symmetrically from the center origin', () {
      const effect = MaskWipeEffect(shape: WipeShape.rect);
      final path = _clipAt(effect, 0.5)!;
      // Half progress from the center is the rect (25, 25)–(75, 75).
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(30, 30)), isTrue);
      expect(path.contains(const Offset(70, 70)), isTrue);
      expect(path.contains(const Offset(20, 50)), isFalse);
      expect(path.contains(const Offset(50, 80)), isFalse);
    });
  });

  group('MaskWipeEffect — diagonal', () {
    test('reveals monotonically: once visible, a point never hides again', () {
      const effect = MaskWipeEffect(shape: WipeShape.diagonal);
      const probes = [Offset(10, 10), Offset(50, 50), Offset(90, 50), Offset(90, 90)];
      var previouslyVisible = <Offset>{};
      for (final progress in const [0.1, 0.3, 0.5, 0.7, 0.9, 0.99]) {
        final path = _clipAt(effect, progress)!;
        final visible = {
          for (final probe in probes)
            if (path.contains(probe)) probe,
        };
        expect(
          visible.containsAll(previouslyVisible),
          isTrue,
          reason: 'at progress $progress the reveal must contain everything from before',
        );
        previouslyVisible = visible;
      }
      expect(previouslyVisible, probes.toSet(), reason: 'near 1 everything is revealed');
    });

    test('sweeps from the top-left: near corners flip first, far corners last', () {
      const effect = MaskWipeEffect(shape: WipeShape.diagonal);
      final early = _clipAt(effect, 0.25)!;
      expect(early.contains(const Offset(10, 10)), isTrue); // 0.1 + 0.1 ≤ 0.5
      expect(early.contains(const Offset(90, 90)), isFalse);
      final late_ = _clipAt(effect, 0.95)!;
      expect(late_.contains(const Offset(85, 85)), isTrue); // 0.85 + 0.85 ≤ 1.9
      expect(late_.contains(const Offset(99, 99)), isFalse); // 0.99 + 0.99 > 1.9
    });
  });

  group('MaskWipeEffect — determinism', () {
    test('two builds at the same progress produce identical clip geometry', () {
      const effect = MaskWipeEffect(origin: Alignment.bottomRight);
      final a = _clipAt(effect, 0.42)!;
      final b = _clipAt(effect, 0.42)!;
      expect(a.getBounds(), b.getBounds());
    });
  });
}
