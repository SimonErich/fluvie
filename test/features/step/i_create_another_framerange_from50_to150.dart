import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/frame_range.dart';
import 'utilities_context.dart';

/// Usage: I create another FrameRange from 50 to 150
Future<void> iCreateAnotherFramerangeFrom50To150(WidgetTester tester) async {
  setAnotherRange(const FrameRange(50, 150));
}
