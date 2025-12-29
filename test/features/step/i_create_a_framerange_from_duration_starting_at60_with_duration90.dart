import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/frame_range.dart';
import 'utilities_context.dart';

/// Usage: I create a FrameRange from duration starting at 60 with duration 90
Future<void> iCreateAFramerangeFromDurationStartingAt60WithDuration90(
  WidgetTester tester,
) async {
  setCurrentRange(FrameRange.fromDuration(60, 90));
}
