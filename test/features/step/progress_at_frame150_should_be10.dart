import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: progress at frame 150 should be 1.0
Future<void> progressAtFrame150ShouldBe10(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.progress(150), equals(1.0));
}
