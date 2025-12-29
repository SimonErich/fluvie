import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: the start should be 30
Future<void> theStartShouldBe30(WidgetTester tester) async {
  final range = getCurrentRange();
  expect(range.start, equals(30));
}
