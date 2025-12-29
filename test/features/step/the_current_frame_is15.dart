import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the current frame is 15
Future<void> theCurrentFrameIs15(WidgetTester tester) async {
  setCurrentFrame(15);
}
