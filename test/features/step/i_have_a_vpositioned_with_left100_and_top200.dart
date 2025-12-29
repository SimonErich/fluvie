import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/layout/v_positioned.dart';
import 'layout_context.dart';

/// Usage: I have a VPositioned with left 100 and top 200
Future<void> iHaveAVpositionedWithLeft100AndTop200(WidgetTester tester) async {
  final widget = VPositioned(
    left: 100,
    top: 200,
    child: Container(key: const Key('child'), width: 50, height: 50, color: Colors.blue),
  );
  setCurrentWidget(widget);
}
