import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: frame 29 should not be contained
Future<void> frame29ShouldNotBeContained(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.contains(29), isFalse);
}
