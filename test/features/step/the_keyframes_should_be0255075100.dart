import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: the keyframes should be 0, 25, 50, 75, 100
Future<void> theKeyframesShouldBe0255075100(WidgetTester tester) async {
  final keyframes = getKeyframes();
  expect(keyframes, equals([0, 25, 50, 75, 100]));
}
