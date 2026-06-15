import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effects/path_effect.dart';

void main() {
  const child = SizedBox(width: 10, height: 10);

  Path line(Offset from, Offset to) => Path()
    ..moveTo(from.dx, from.dy)
    ..lineTo(to.dx, to.dy);

  /// The outermost Transform is the translation; returns its offset.
  Offset translationOf(Widget built) {
    final transform = built as Transform;
    final storage = transform.transform.storage;
    return Offset(storage[12], storage[13]);
  }

  group('translation along the path', () {
    test('a straight line at p 0.5 translates to the midpoint', () {
      final effect = PathEffect(line(Offset.zero, const Offset(100, 0)), orient: false);
      expect(translationOf(effect.build(child, 0.5)), const Offset(50, 0));
    });

    test('p 0 and p 1 hit the endpoints', () {
      final effect = PathEffect(line(const Offset(10, 20), const Offset(110, 20)), orient: false);
      expect(translationOf(effect.build(child, 0)), const Offset(10, 20));
      expect(translationOf(effect.build(child, 1)), const Offset(110, 20));
    });

    test('progress is measured by arc length across segments', () {
      final corner = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..lineTo(100, 100);
      final effect = PathEffect(corner, orient: false);
      expect(translationOf(effect.build(child, 0.75)), const Offset(100, 50));
    });

    test('progress outside [0, 1] clamps to the endpoints', () {
      final effect = PathEffect(line(Offset.zero, const Offset(100, 0)), orient: false);
      expect(translationOf(effect.build(child, 1.2)), const Offset(100, 0));
      expect(translationOf(effect.build(child, -0.2)), Offset.zero);
    });
  });

  group('orient', () {
    test('orient false mounts no rotation transform', () {
      final effect = PathEffect(line(Offset.zero, const Offset(0, 100)), orient: false);
      final built = effect.build(child, 0.5) as Transform;
      expect(built.child, same(child));
    });

    test('orient true on a downward vertical line rotates 90 degrees', () {
      final effect = PathEffect(line(Offset.zero, const Offset(0, 100)));
      final built = effect.build(child, 0.5) as Transform;
      final rotate = built.child! as Transform;
      final storage = rotate.transform.storage;
      expect(storage[0], closeTo(math.cos(math.pi / 2), 1e-9)); // ~0
      expect(storage[1], closeTo(math.sin(math.pi / 2), 1e-9)); // 1
    });

    test('orient true along +x is the identity rotation', () {
      final effect = PathEffect(line(Offset.zero, const Offset(100, 0)));
      final built = effect.build(child, 0.5) as Transform;
      final rotate = built.child! as Transform;
      expect(rotate.transform.storage[0], closeTo(1, 1e-9));
      expect(rotate.transform.storage[1], closeTo(0, 1e-9));
    });
  });

  group('determinism', () {
    test('two builds at the same progress produce identical transforms', () {
      final effect = PathEffect(line(Offset.zero, const Offset(100, 60)));
      final a = effect.build(child, 0.37) as Transform;
      final b = effect.build(child, 0.37) as Transform;
      expect(a.transform.storage, b.transform.storage);
      final aInner = a.child! as Transform;
      final bInner = b.child! as Transform;
      expect(aInner.transform.storage, bInner.transform.storage);
    });
  });

  group('degenerate paths', () {
    test('an empty path leaves the child untouched', () {
      final effect = PathEffect(Path());
      expect(effect.build(child, 0.5), same(child));
    });
  });
}
