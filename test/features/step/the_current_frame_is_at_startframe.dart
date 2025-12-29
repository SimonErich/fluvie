import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the current frame is at startFrame
Future<void> theCurrentFrameIsAtStartframe(WidgetTester tester) async {
  final startFrame = getStartFrame();
  if (startFrame == null) {
    throw StateError('No startFrame has been set');
  }
  setCurrentFrame(startFrame);
}
