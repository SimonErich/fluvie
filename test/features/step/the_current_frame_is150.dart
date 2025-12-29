import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the current frame is 150
Future<void> theCurrentFrameIs150(WidgetTester tester) async {
  setCurrentFrame(150);
}
