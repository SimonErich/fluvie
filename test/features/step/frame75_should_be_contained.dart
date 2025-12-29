import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: frame 75 should be contained
Future<void> frame75ShouldBeContained(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.contains(75), isTrue);
}
