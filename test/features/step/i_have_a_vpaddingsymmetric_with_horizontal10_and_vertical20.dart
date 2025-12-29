import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_padding.dart';
import 'layout_context.dart';

/// Usage: I have a VPadding.symmetric with horizontal 10 and vertical 20
Future<void> iHaveAVpaddingsymmetricWithHorizontal10AndVertical20(
  WidgetTester tester,
) async {
  final widget = VPadding.symmetric(
    horizontal: 10,
    vertical: 20,
    child: Container(
      key: const Key('child'),
      width: 50,
      height: 50,
      color: Colors.blue,
    ),
  );
  setCurrentWidget(widget);
}
