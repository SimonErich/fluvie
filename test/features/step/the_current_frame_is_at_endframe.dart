import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the current frame is at endFrame
Future<void> theCurrentFrameIsAtEndframe(WidgetTester tester) async {
  final endFrame = getEndFrame();
  if (endFrame == null) {
    throw StateError('No endFrame has been set');
  }
  setCurrentFrame(endFrame);
}
