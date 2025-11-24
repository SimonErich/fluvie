import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';

Future<void> theFramesequencerCapturesFrame50(WidgetTester tester) async {
  // Re-pump with frame 50
  await tester.pumpWidget(
    MaterialApp(
      home: FrameProvider(
        frame: 50,
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
                    child: Container(
                      width: 10,
                      height: 10,
                      color: Colors.red,
                    ),
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
