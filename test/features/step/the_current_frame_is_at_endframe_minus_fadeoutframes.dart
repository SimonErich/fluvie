import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the current frame is at endFrame minus fadeOutFrames
Future<void> theCurrentFrameIsAtEndframeMinusFadeoutframes(
  WidgetTester tester,
) async {
  final endFrame = getEndFrame();
  final fadeOutFrames = getFadeOutFrames();
  if (endFrame == null || fadeOutFrames == null) {
    throw StateError('No endFrame or fadeOutFrames has been set');
  }
  setCurrentFrame(endFrame - fadeOutFrames);
}
