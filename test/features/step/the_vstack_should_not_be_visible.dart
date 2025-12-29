import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'layout_context.dart';

/// Usage: the VStack should not be visible
Future<void> theVstackShouldNotBeVisible(WidgetTester tester) async {
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

  // The Layer widget should render a SizedBox.shrink when not visible
  expect(find.byType(SizedBox), findsWidgets);
}
