import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_column.dart';
import 'package:fluvie/src/declarative/layout/stagger_config.dart';
import 'layout_context.dart';

/// Usage: I have a VColumn with stagger delay 15
Future<void> iHaveAVcolumnWithStaggerDelay15(WidgetTester tester) async {
  final widget = VColumn(
    stagger: StaggerConfig(delay: 15),
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
    ],
  );
  setCurrentWidget(widget);
}
