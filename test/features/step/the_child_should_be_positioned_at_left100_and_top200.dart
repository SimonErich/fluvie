import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the child should be positioned at left 100 and top 200
Future<void> theChildShouldBePositionedAtLeft100AndTop200(
    WidgetTester tester) async {
  final widget = getCurrentWidget();
  // Wrap in a Stack since Positioned requires it
  await tester.pumpWidget(MaterialApp(home: Stack(children: [widget])));

  // Find the Positioned widget
  final positioned = tester.widget<Positioned>(find.byType(Positioned));
  expect(positioned.left, equals(100));
  expect(positioned.top, equals(200));
}
