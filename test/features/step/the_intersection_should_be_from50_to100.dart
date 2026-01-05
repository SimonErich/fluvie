import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/frame_range.dart';
import 'utilities_context.dart';

/// Usage: the intersection should be from 50 to 100
Future<void> theIntersectionShouldBeFrom50To100(WidgetTester tester) async {
  final range1 = getCurrentRange();
  final range2 = getAnotherRange();
  final intersection = range1.intersection(range2);
  expect(intersection, isNotNull);
  expect(intersection, equals(const FrameRange(50, 100)));
}
