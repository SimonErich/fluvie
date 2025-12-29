import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: progress at frame 50 should be 0.5
Future<void> progressAtFrame50ShouldBe05(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.progress(50), equals(0.5));
}
