import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the current frame is 0
Future<void> theCurrentFrameIs0(WidgetTester tester) async {
  setCurrentFrame(0);
}
