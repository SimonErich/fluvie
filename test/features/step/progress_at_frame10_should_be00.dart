import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: progress at frame -10 should be 0.0
Future<void> progressAtFrame10ShouldBe00(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.progress(-10), equals(0.0));
}
