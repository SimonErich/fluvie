import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/easing.dart';

/// Step: And the Easing class should provide cubic curves
Future<void> theEasingClassShouldProvideCubicCurves(WidgetTester tester) async {
  expect(Easing.easeInCubic, isA<Curve>());
  expect(Easing.easeOutCubic, isA<Curve>());
  expect(Easing.easeInOutCubic, isA<Curve>());
}
