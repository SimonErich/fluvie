import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> iDefineAVideocompositionWrappedInARepaintboundary(
  WidgetTester tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: RepaintBoundary(
        key: Key('video-boundary'),
        child: VideoComposition(
          fps: 30,
          durationInFrames: 60,
          child: SizedBox(),
        ),
      ),
    ),
  );
}
