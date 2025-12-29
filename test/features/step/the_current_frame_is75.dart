import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the current frame is 75
Future<void> theCurrentFrameIs75(WidgetTester tester) async {
  setCurrentFrame(75);
}
