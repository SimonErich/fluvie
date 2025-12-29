import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: frame 120 should not be contained
Future<void> frame120ShouldNotBeContained(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.contains(120), isFalse);
}
