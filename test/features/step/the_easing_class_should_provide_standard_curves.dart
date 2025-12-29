import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/easing.dart';

/// Step: Then the Easing class should provide standard curves
Future<void> theEasingClassShouldProvideStandardCurves(
  WidgetTester tester,
) async {
  expect(Easing.linear, isA<Curve>());
  expect(Easing.easeIn, isA<Curve>());
  expect(Easing.easeOut, isA<Curve>());
  expect(Easing.easeInOut, isA<Curve>());
}
