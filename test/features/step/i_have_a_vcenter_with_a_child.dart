import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_center.dart';
import 'layout_context.dart';

/// Usage: I have a VCenter with a child
Future<void> iHaveAVcenterWithAChild(WidgetTester tester) async {
  final widget = VCenter(
    child: Container(
      key: const Key('child'),
      width: 50,
      height: 50,
      color: Colors.blue,
    ),
  );
  setCurrentWidget(widget);
}
