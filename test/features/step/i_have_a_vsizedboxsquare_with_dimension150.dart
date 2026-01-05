import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_sized_box.dart';
import 'layout_context.dart';

/// Usage: I have a VSizedBox.square with dimension 150
Future<void> iHaveAVsizedboxsquareWithDimension150(WidgetTester tester) async {
  const widget = VSizedBox.square(
    dimension: 150,
    child: ColoredBox(key: Key('child'), color: Colors.blue),
  );
  setCurrentWidget(widget);
}
