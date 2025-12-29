import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
// Import for FrameProvider

Future<void>
iUseATimeconsumerToAnimateACirclesXPositionFrom0To100BetweenFrame0AndFrame100(
  WidgetTester tester,
) async {
  // We start at frame 0
  await tester.pumpWidget(
    MaterialApp(
      home: FrameProvider(
        frame: 0,
        child: VideoComposition(
          fps: 30,
          durationInFrames: 100,
          child: TimeConsumer(
            builder: (context, frame, progress) {
              final x = (frame / 100) * 100;
              return Stack(
                children: [
                  Positioned(
                    left: x,
                    top: 0,
                    child: Container(width: 10, height: 10, color: Colors.red),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
