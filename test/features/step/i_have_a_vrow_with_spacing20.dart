import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_row.dart';
import 'layout_context.dart';

/// Usage: I have a VRow with spacing 20
Future<void> iHaveAVrowWithSpacing20(WidgetTester tester) async {
  final widget = VRow(
    spacing: 20,
    children: [
      Container(key: const Key('child1'), width: 50, height: 50, color: Colors.red),
      Container(key: const Key('child2'), width: 50, height: 50, color: Colors.blue),
    ],
  );
  setCurrentWidget(widget);
}
