import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_stack.dart';
import 'layout_context.dart';

/// Usage: I have a VStack with startFrame 30 and endFrame 120
Future<void> iHaveAVstackWithStartframe30AndEndframe120(
    WidgetTester tester) async {
  final widget = VStack(
    startFrame: 30,
    endFrame: 120,
    children: [
      Container(key: const Key('content'), width: 100, height: 100, color: Colors.red),
    ],
  );
  setCurrentWidget(widget);
  setStartFrame(30);
  setEndFrame(120);
}
