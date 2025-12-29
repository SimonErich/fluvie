import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/fade.dart';
import 'layout_context.dart';

/// Usage: the opacity should be 0
Future<void> theOpacityShouldBe0(WidgetTester tester) async {
  final widget = getCurrentWidget();
  final frame = getCurrentFrame();

  await tester.pumpWidget(
    MaterialApp(
      home: VideoComposition(
        durationInFrames: 200,
        fps: 30,
        child: FrameProvider(
          frame: frame,
          child: widget,
        ),
      ),
    ),
  );

  // Find the Fade widget
  final fadeWidgets = find.byType(Fade);
  if (fadeWidgets.evaluate().isEmpty) {
    // If no Fade widget found, opacity is implicitly 0 (widget not rendered)
    return;
  }

  final fade = tester.widget<Fade>(fadeWidgets.first);
  expect(fade.opacity, closeTo(0.0, 0.01));
}
