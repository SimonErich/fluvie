import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: the ranges should overlap
Future<void> theRangesShouldOverlap(WidgetTester tester) async {
  final range1 = getCurrentRange();
  final range2 = getAnotherRange();
  expect(range1.overlaps(range2), isTrue);
}
