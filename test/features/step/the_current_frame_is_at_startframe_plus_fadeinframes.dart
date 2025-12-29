import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the current frame is at startFrame plus fadeInFrames
Future<void> theCurrentFrameIsAtStartframePlusFadeinframes(
    WidgetTester tester) async {
  final startFrame = getStartFrame();
  final fadeInFrames = getFadeInFrames();
  if (startFrame == null || fadeInFrames == null) {
    throw StateError('No startFrame or fadeInFrames has been set');
  }
  setCurrentFrame(startFrame + fadeInFrames);
}
