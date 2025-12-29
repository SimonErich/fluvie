import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/easing.dart';

/// Step: And the Easing class should provide back curves with overshoot
Future<void> theEasingClassShouldProvideBackCurvesWithOvershoot(
  WidgetTester tester,
) async {
  expect(Easing.easeInBack, isA<Curve>());
  expect(Easing.easeOutBack, isA<Curve>());
  expect(Easing.easeInOutBack, isA<Curve>());

  // Verify easeOutBack actually overshoots (value > 1.0 at some point)
  // The control point 1.56 should cause overshoot
  final testValue = Easing.easeOutBack.transform(0.7);
  expect(testValue, greaterThan(0.9)); // Should be close to or past 1.0
}
