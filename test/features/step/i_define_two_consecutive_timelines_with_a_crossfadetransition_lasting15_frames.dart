import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> iDefineTwoConsecutiveTimelinesWithACrossfadetransitionLasting15Frames(
    WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VideoComposition(
        fps: 30,
        durationInFrames: 100,
        child: CrossFadeTransition(
          durationInFrames: 15,
          child1: Container(color: Colors.red),
          child2: Container(color: Colors.blue),
        ),
      ),
    ),
  );
}
