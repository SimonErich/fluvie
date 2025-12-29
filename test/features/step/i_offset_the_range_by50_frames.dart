import 'package:flutter_test/flutter_test.dart';
import 'utilities_context.dart';

/// Usage: I offset the range by 50 frames
Future<void> iOffsetTheRangeBy50Frames(WidgetTester tester) async {
  final range = getCurrentRange();
  final offsetRange = range.offset(50);
  setCurrentRange(offsetRange);
}
