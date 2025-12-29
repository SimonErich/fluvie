import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: progress at frame 100 should be 1.0
Future<void> progressAtFrame100ShouldBe10(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.progress(100), equals(1.0));
}
