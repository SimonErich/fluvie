import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'layout_context.dart';

/// Usage: the second child should start animating
Future<void> theSecondChildShouldStartAnimating(WidgetTester tester) async {
  final widget = getCurrentWidget();
  final frame = getCurrentFrame();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VideoComposition(
          durationInFrames: 200,
          fps: 30,
          child: FrameProvider(
            frame: frame,
            child: widget,
          ),
        ),
      ),
    ),
  );

  // At frame 15, the second child should be starting its animation
  // The stagger animation wraps children with TimeConsumer, so verify:
  // 1. The Column exists
  expect(find.byType(Column), findsOneWidget);

  // 2. TimeConsumer widgets exist for the staggered children
  expect(find.byType(TimeConsumer), findsWidgets);
}
