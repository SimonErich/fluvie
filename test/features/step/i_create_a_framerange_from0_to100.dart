import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/frame_range.dart';
import 'utilities_context.dart';

/// Usage: I create a FrameRange from 0 to 100
Future<void> iCreateAFramerangeFrom0To100(WidgetTester tester) async {
  setCurrentRange(FrameRange(0, 100));
}
