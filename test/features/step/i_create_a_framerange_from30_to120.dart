import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/frame_range.dart';
import 'utilities_context.dart';

/// Usage: I create a FrameRange from 30 to 120
Future<void> iCreateAFramerangeFrom30To120(WidgetTester tester) async {
  setCurrentRange(const FrameRange(30, 120));
}
