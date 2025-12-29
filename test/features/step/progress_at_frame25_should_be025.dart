import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: progress at frame 25 should be 0.25
Future<void> progressAtFrame25ShouldBe025(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.progress(25), equals(0.25));
}
