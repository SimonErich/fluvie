import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_padding.dart';
import 'layout_context.dart';

/// Usage: I have a VPadding with padding 20
Future<void> iHaveAVpaddingWithPadding20(WidgetTester tester) async {
  final widget = VPadding.all(
    20,
    child: Container(
      key: const Key('child'),
      width: 50,
      height: 50,
      color: Colors.blue,
    ),
  );
  setCurrentWidget(widget);
}
