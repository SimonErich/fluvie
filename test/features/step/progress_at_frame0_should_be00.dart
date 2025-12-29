import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: progress at frame 0 should be 0.0
Future<void> progressAtFrame0ShouldBe00(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.progress(0), equals(0.0));
}
