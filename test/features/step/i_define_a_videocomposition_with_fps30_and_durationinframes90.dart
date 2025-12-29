import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> iDefineAVideocompositionWithFps30AndDurationinframes90(
  WidgetTester tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: VideoComposition(fps: 30, durationInFrames: 90, child: SizedBox()),
    ),
  );
}
