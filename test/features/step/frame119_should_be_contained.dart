import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: frame 119 should be contained
Future<void> frame119ShouldBeContained(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.contains(119), isTrue);
}
