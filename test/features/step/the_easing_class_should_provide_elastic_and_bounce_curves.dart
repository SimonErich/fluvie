import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/easing.dart';

/// Step: And the Easing class should provide elastic and bounce curves
Future<void> theEasingClassShouldProvideElasticAndBounceCurves(
  WidgetTester tester,
) async {
  expect(Easing.elastic, isA<Curve>());
  expect(Easing.elasticIn, isA<Curve>());
  expect(Easing.elasticInOut, isA<Curve>());
  expect(Easing.bounce, isA<Curve>());
  expect(Easing.bounceIn, isA<Curve>());
  expect(Easing.bounceInOut, isA<Curve>());
}
