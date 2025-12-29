import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_center.dart';
import 'layout_context.dart';

/// Usage: I have a VCenter with fadeOutFrames 15
Future<void> iHaveAVcenterWithFadeoutframes15(WidgetTester tester) async {
  final widget = VCenter(
    startFrame: 30,
    endFrame: 100,
    fadeOutFrames: 15,
    child: Container(
      key: const Key('child'),
      width: 50,
      height: 50,
      color: Colors.blue,
    ),
  );
  setCurrentWidget(widget);
  setStartFrame(30);
  setEndFrame(100);
  setFadeOutFrames(15);
}
