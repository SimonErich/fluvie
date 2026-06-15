import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/angle.dart';

void main() {
  group('Angle constructors', () {
    test('deg 90 is 0.25 turns', () {
      expect(const Angle.deg(90).turns, closeTo(0.25, 1e-12));
    });

    test('turns round-trips', () {
      const angle = Angle.turns(0.75);
      expect(angle.turns, 0.75);
      expect(angle.degrees, closeTo(270, 1e-9));
    });

    test('rad 2pi is one turn', () {
      expect(const Angle.rad(2 * math.pi).turns, closeTo(1, 1e-12));
    });
  });

  group('unit getters', () {
    test('degrees converts from turns', () {
      expect(const Angle.turns(0.5).degrees, closeTo(180, 1e-9));
    });

    test('radians converts from turns', () {
      expect(const Angle.deg(180).radians, closeTo(math.pi, 1e-12));
    });

    test('degrees round-trips through radians', () {
      expect(const Angle.rad(math.pi / 4).degrees, closeTo(45, 1e-9));
    });
  });

  group('equality across constructors', () {
    test('the same angle from different units is equal', () {
      expect(const Angle.deg(90), const Angle.turns(0.25));
      expect(const Angle.deg(90).hashCode, const Angle.turns(0.25).hashCode);
    });

    test('different angles are unequal', () {
      expect(const Angle.deg(90), isNot(const Angle.deg(91)));
    });

    test('toString reports turns', () {
      expect(const Angle.turns(0.25).toString(), 'Angle.turns(0.25)');
    });
  });

  group('Keyframe interop', () {
    test('rotation accepts Angle.deg(90).turns', () {
      // §5: `Keyframe(rotation: Angle.deg(90).turns)` — rotation stays double.
      expect(const Angle.deg(90).turns, isA<double>());
    });
  });
}
