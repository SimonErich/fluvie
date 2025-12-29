import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> iUseALayerstackContainingARedBoxAndAGreenCircle(
  WidgetTester tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VideoComposition(
        fps: 30,
        durationInFrames: 60,
        child: LayerStack(
          children: [
            Container(width: 100, height: 100, color: Colors.red),
            Container(width: 50, height: 50, color: Colors.green),
          ],
        ),
      ),
    ),
  );
}
