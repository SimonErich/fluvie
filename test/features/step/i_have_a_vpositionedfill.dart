import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_positioned.dart';
import 'layout_context.dart';

/// Usage: I have a VPositioned.fill
Future<void> iHaveAVpositionedfill(WidgetTester tester) async {
  final widget = VPositioned.fill(
    child: Container(key: const Key('child'), color: Colors.blue),
  );
  setCurrentWidget(widget);
}
