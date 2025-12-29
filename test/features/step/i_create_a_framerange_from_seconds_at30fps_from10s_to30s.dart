import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/frame_range.dart';
import 'utilities_context.dart';

/// Usage: I create a FrameRange from seconds at 30fps from 1.0s to 3.0s
Future<void> iCreateAFramerangeFromSecondsAt30fpsFrom10sTo30s(
    WidgetTester tester) async {
  setCurrentRange(FrameRange.fromSeconds(30, 1.0, 3.0));
}
