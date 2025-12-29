import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_row.dart';
import 'layout_context.dart';

/// Usage: I have a VRow with three children
Future<void> iHaveAVrowWithThreeChildren(WidgetTester tester) async {
  final widget = VRow(
    children: [
      Container(
        key: const Key('child1'),
        width: 50,
        height: 50,
        color: Colors.red,
      ),
      Container(
        key: const Key('child2'),
        width: 50,
        height: 50,
        color: Colors.green,
      ),
      Container(
        key: const Key('child3'),
        width: 50,
        height: 50,
        color: Colors.blue,
      ),
    ],
  );
  setCurrentWidget(widget);
}
