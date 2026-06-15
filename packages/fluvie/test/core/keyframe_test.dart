import 'package:flutter/painting.dart' show Alignment, Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/keyframe.dart';

const red = Color(0xFFFF0000);
const blue = Color(0xFF0000FF);

void main() {
  group('Keyframe.natural', () {
    test('leaves every animatable field null with a centered origin', () {
      expect(Keyframe.natural.opacity, isNull);
      expect(Keyframe.natural.x, isNull);
      expect(Keyframe.natural.y, isNull);
      expect(Keyframe.natural.scale, isNull);
      expect(Keyframe.natural.scaleX, isNull);
      expect(Keyframe.natural.scaleY, isNull);
      expect(Keyframe.natural.rotation, isNull);
      expect(Keyframe.natural.skewX, isNull);
      expect(Keyframe.natural.skewY, isNull);
      expect(Keyframe.natural.blur, isNull);
      expect(Keyframe.natural.color, isNull);
      expect(Keyframe.natural.origin, Alignment.center);
    });

    test('equals a default-constructed Keyframe', () {
      // Constructing the default directly is the point of this test.
      // ignore: use_named_constants
      expect(Keyframe.natural, equals(const Keyframe()));
    });
  });

  group('operator + (merge)', () {
    test('the right operand wins on overlapping non-null fields', () {
      const left = Keyframe(opacity: 0.2, x: 1, scale: 2);
      const right = Keyframe(opacity: 0.9, scale: 3);
      final merged = left + right;
      expect(merged.opacity, 0.9);
      expect(merged.scale, 3);
      expect(merged.x, 1);
    });

    test("keeps the left operand's fields where the right is null", () {
      const left = Keyframe(
        opacity: 0.5,
        x: 1,
        y: 2,
        scaleX: 3,
        scaleY: 4,
        rotation: 0.25,
        skewX: 0.1,
        skewY: 0.2,
        blur: 6,
        color: red,
      );
      final merged = left + const Keyframe(y: 9);
      expect(merged.opacity, 0.5);
      expect(merged.x, 1);
      expect(merged.y, 9);
      expect(merged.scaleX, 3);
      expect(merged.scaleY, 4);
      expect(merged.rotation, 0.25);
      expect(merged.skewX, 0.1);
      expect(merged.skewY, 0.2);
      expect(merged.blur, 6);
      expect(merged.color, red);
    });

    test('natural + k is k', () {
      const k = Keyframe(opacity: 0.7, x: -1, blur: 3, color: blue, origin: Alignment.topLeft);
      expect(Keyframe.natural + k, equals(k));
    });

    test("k + natural keeps k's nullable fields but takes the right operand's origin", () {
      const k = Keyframe(opacity: 0.7, blur: 3, origin: Alignment.topLeft);
      final merged = k + Keyframe.natural;
      expect(merged.opacity, 0.7);
      expect(merged.blur, 3);
      expect(merged.origin, Alignment.center);
    });

    test('origin always comes from the right operand', () {
      const left = Keyframe(origin: Alignment.topLeft);
      const right = Keyframe(origin: Alignment.bottomRight);
      expect((left + right).origin, Alignment.bottomRight);
    });
  });

  group('lerp', () {
    const a = Keyframe(
      opacity: 0,
      x: 0,
      y: 0,
      scale: 1,
      scaleX: 1,
      scaleY: 1,
      rotation: 0,
      skewX: 0,
      skewY: 0,
      blur: 0,
    );
    const b = Keyframe(
      opacity: 1,
      x: 2,
      y: 4,
      scale: 3,
      scaleX: 5,
      scaleY: 7,
      rotation: 1,
      skewX: 2,
      skewY: 4,
      blur: 8,
    );

    test('interpolates every numeric field at the midpoint', () {
      final mid = Keyframe.lerp(a, b, 0.5);
      expect(mid.opacity, 0.5);
      expect(mid.x, 1);
      expect(mid.y, 2);
      expect(mid.scale, 2);
      expect(mid.scaleX, 3);
      expect(mid.scaleY, 4);
      expect(mid.rotation, 0.5);
      expect(mid.skewX, 1);
      expect(mid.skewY, 2);
      expect(mid.blur, 4);
    });

    test('returns the endpoints at t = 0 and t = 1', () {
      expect(Keyframe.lerp(a, b, 0), equals(a));
      expect(Keyframe.lerp(a, b, 1), equals(b));
    });

    test('substitutes the natural identity for a null side', () {
      expect(Keyframe.lerp(Keyframe.natural, const Keyframe(opacity: 0), 0.5).opacity, 0.5);
      expect(Keyframe.lerp(Keyframe.natural, const Keyframe(x: 1), 0.5).x, 0.5);
      expect(Keyframe.lerp(Keyframe.natural, const Keyframe(y: -2), 0.5).y, -1);
      expect(Keyframe.lerp(Keyframe.natural, const Keyframe(scale: 3), 0.5).scale, 2);
      expect(Keyframe.lerp(Keyframe.natural, const Keyframe(scaleX: 0), 0.5).scaleX, 0.5);
      expect(Keyframe.lerp(Keyframe.natural, const Keyframe(scaleY: 5), 0.5).scaleY, 3);
      expect(Keyframe.lerp(Keyframe.natural, const Keyframe(rotation: 1), 0.25).rotation, 0.25);
      expect(Keyframe.lerp(Keyframe.natural, const Keyframe(skewX: 2), 0.5).skewX, 1);
      expect(Keyframe.lerp(const Keyframe(skewY: 2), Keyframe.natural, 0.5).skewY, 1);
      expect(Keyframe.lerp(const Keyframe(blur: 4), Keyframe.natural, 0.5).blur, 2);
    });

    test('a field that is null on both sides stays null', () {
      final mid = Keyframe.lerp(
        const Keyframe(opacity: 1),
        const Keyframe(opacity: 0),
        0.5,
      );
      expect(mid.opacity, 0.5);
      expect(mid.x, isNull);
      expect(mid.scale, isNull);
      expect(mid.blur, isNull);
      expect(mid.color, isNull);
    });

    test('color follows Color.lerp when both sides are set', () {
      final mid = Keyframe.lerp(
        const Keyframe(color: red),
        const Keyframe(color: blue),
        0.5,
      );
      expect(mid.color, Color.lerp(red, blue, 0.5));
    });

    test('color follows Color.lerp null semantics for a one-sided lerp', () {
      final quarter = Keyframe.lerp(Keyframe.natural, const Keyframe(color: red), 0.25);
      expect(quarter.color, Color.lerp(null, red, 0.25));
    });

    test('origin interpolates between the two origins', () {
      final mid = Keyframe.lerp(
        const Keyframe(origin: Alignment.topLeft),
        const Keyframe(origin: Alignment.bottomRight),
        0.5,
      );
      expect(mid.origin, Alignment.center);
    });

    test('t outside [0, 1] extrapolates linearly', () {
      expect(Keyframe.lerp(const Keyframe(x: 0), const Keyframe(x: 1), 2).x, 2);
      expect(Keyframe.lerp(const Keyframe(opacity: 1), const Keyframe(opacity: 0), 2).opacity, -1);
      expect(Keyframe.lerp(const Keyframe(blur: 2), const Keyframe(blur: 4), -1).blur, 0);
    });
  });

  group('equality', () {
    test('keyframes with the same field values are equal and share a hash code', () {
      const k1 = Keyframe(opacity: 0.5, x: 1, color: red, origin: Alignment.topLeft);
      const k2 = Keyframe(opacity: 0.5, x: 1, color: red, origin: Alignment.topLeft);
      expect(k1, equals(k2));
      expect(k1.hashCode, equals(k2.hashCode));
    });

    test('any differing field breaks equality', () {
      const base = Keyframe(opacity: 0.5, x: 1, color: red);
      expect(base, isNot(equals(const Keyframe(opacity: 0.6, x: 1, color: red))));
      expect(base, isNot(equals(const Keyframe(opacity: 0.5, x: 1, color: blue))));
      expect(base, isNot(equals(const Keyframe(opacity: 0.5, x: 1))));
      expect(
        base,
        isNot(equals(const Keyframe(opacity: 0.5, x: 1, color: red, origin: Alignment.topLeft))),
      );
    });
  });

  group('toString', () {
    test('lists only the non-null fields', () {
      final text = const Keyframe(opacity: 0.5, blur: 2).toString();
      expect(text, contains('opacity: 0.5'));
      expect(text, contains('blur: 2.0'));
      expect(text, isNot(contains('x:')));
      expect(text, isNot(contains('color')));
    });

    test('renders the natural keyframe as an empty constructor call', () {
      expect(Keyframe.natural.toString(), 'Keyframe()');
    });

    test('shows the origin only when it differs from the default', () {
      expect(const Keyframe(origin: Alignment.topLeft).toString(), contains('origin'));
      expect(const Keyframe(opacity: 1).toString(), isNot(contains('origin')));
    });
  });
}
