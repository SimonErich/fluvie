import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: the duration should be 90 frames
Future<void> theDurationShouldBe90Frames(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.duration, equals(90));
}
