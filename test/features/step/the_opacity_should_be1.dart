import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/fade.dart';
import 'layout_context.dart';

/// Usage: the opacity should be 1
Future<void> theOpacityShouldBe1(WidgetTester tester) async {
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

  // The content should be visible
  expect(find.byKey(const Key('child')), findsOneWidget);

  // Try to find the Fade widget and check opacity
  final fadeWidgets = find.byType(Fade);
  if (fadeWidgets.evaluate().isNotEmpty) {
    final fade = tester.widget<Fade>(fadeWidgets.first);
    expect(fade.opacity, closeTo(1.0, 0.01));
  }
  // If no Fade widget, the opacity is implicitly 1.0 (fully visible)
}
