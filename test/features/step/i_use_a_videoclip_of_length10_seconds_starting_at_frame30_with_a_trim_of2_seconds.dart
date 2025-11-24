import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> iUseAVideoclipOfLength10SecondsStartingAtFrame30WithATrimOf2Seconds(
    WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: VideoComposition(
        fps: 30,
        durationInFrames: 300,
        child: VideoClip(
          startFrame: 30,
          durationInFrames: 300, // 10 seconds
          assetPath: 'assets/video.mp4',
          trimStartFrame: 60, // 2 seconds
        ),
      ),
    ),
  );
}
