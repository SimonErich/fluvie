import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_stack.dart';
import 'layout_context.dart';

/// Usage: I have a VStack with two children
Future<void> iHaveAVstackWithTwoChildren(WidgetTester tester) async {
  final widget = VStack(
    children: [
      Container(
        key: const Key('child1'),
        width: 100,
        height: 100,
        color: Colors.red,
      ),
      Container(
        key: const Key('child2'),
        width: 50,
        height: 50,
        color: Colors.blue,
      ),
    ],
  );
  setCurrentWidget(widget);
}
