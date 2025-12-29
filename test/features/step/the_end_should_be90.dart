import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: the end should be 90
Future<void> theEndShouldBe90(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.end, equals(90));
}
