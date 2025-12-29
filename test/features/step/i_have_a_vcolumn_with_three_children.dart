import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_column.dart';
import 'layout_context.dart';

/// Usage: I have a VColumn with three children
Future<void> iHaveAVcolumnWithThreeChildren(WidgetTester tester) async {
  final widget = VColumn(
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
