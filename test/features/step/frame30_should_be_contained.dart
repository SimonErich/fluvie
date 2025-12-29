import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: frame 30 should be contained
Future<void> frame30ShouldBeContained(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.contains(30), isTrue);
}
