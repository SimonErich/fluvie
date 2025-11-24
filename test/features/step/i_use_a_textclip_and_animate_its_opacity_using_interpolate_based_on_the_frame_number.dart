import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> iUseATextclipAndAnimateItsOpacityUsingInterpolateBasedOnTheFrameNumber(
    WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VideoComposition(
        fps: 30,
        durationInFrames: 60,
        child: TimeConsumer(
          builder: (context, frame, progress) {
            final opacity = interpolate(frame, [0, 60], [0.0, 1.0]);
            return Opacity(
              opacity: opacity,
              child: const TextClip(
                startFrame: 0,
                durationInFrames: 60,
                text: 'Hello',
              ),
            );
          },
        ),
      ),
    ),
  );
}
