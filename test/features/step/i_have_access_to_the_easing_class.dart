import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/easing.dart';

/// Step: Given I have access to the Easing class
Future<void> iHaveAccessToTheEasingClass(WidgetTester tester) async {
  // Verify the Easing class exists and is accessible
  expect(Easing, isNotNull);
}
