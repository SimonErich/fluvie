import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> iUseACollagetemplatesplitscreenWithTwoChildClips(
    WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VideoComposition(
        fps: 30,
        durationInFrames: 60,
        child: CollageTemplate.splitScreen(
          children: [
            Container(color: Colors.red),
            Container(color: Colors.blue),
          ],
        ),
      ),
    ),
  );
}
