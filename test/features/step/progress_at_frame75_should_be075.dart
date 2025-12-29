import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: progress at frame 75 should be 0.75
Future<void> progressAtFrame75ShouldBe075(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.progress(75), equals(0.75));
}
