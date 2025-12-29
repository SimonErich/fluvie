import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_sized_box.dart';
import 'layout_context.dart';

/// Usage: I have a VSizedBox with width 200 and height 100
Future<void> iHaveAVsizedboxWithWidth200AndHeight100(
    WidgetTester tester) async {
  final widget = VSizedBox(
    width: 200,
    height: 100,
    child: Container(key: const Key('child'), color: Colors.blue),
  );
  setCurrentWidget(widget);
}
