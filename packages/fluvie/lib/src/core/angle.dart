import 'dart:math' as math;

import 'package:fluvie/src/core/keyframe.dart';
import 'package:meta/meta.dart';

/// A rotation expressed in whichever unit reads best at the call site.
///
/// [Keyframe.rotation] is a plain `double` in turns (`1.0` = 360°); [Angle]
/// is the conversion sugar for people who think in degrees or radians:
///
/// ```dart
/// Keyframe(rotation: Angle.deg(90).turns) // a quarter turn
/// ```
///
/// Angles are stored canonically in turns, so the same rotation compares
/// equal whichever constructor produced it.
@immutable
final class Angle {
  // coverage:ignore-start const ctor artifacts angle_test pins the canonical turns each ctor stores plus equality and toString
  /// An angle of [degrees] degrees (`360` = one full turn).
  const Angle.deg(double degrees) : turns = degrees / 360;

  /// An angle of [turns] full turns (`1.0` = 360°).
  const Angle.turns(this.turns);

  /// An angle of [radians] radians (`2π` = one full turn).
  const Angle.rad(double radians) : turns = radians / (2 * math.pi);
  // coverage:ignore-end

  /// The angle in turns — the unit [Keyframe.rotation] expects.
  final double turns;

  /// The angle in degrees.
  double get degrees => turns * 360;

  /// The angle in radians.
  double get radians => turns * 2 * math.pi;

  @override
  bool operator ==(Object other) => other is Angle && other.turns == turns;

  @override
  int get hashCode => Object.hash(Angle, turns);

  @override
  String toString() => 'Angle.turns($turns)';
}
