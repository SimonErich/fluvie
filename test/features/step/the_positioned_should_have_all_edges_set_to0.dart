import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the positioned should have all edges set to 0
Future<void> thePositionedShouldHaveAllEdgesSetTo0(WidgetTester tester) async {
  final widget = getCurrentWidget();
  // Wrap in a Stack since Positioned requires it
  await tester.pumpWidget(MaterialApp(home: Stack(children: [widget])));

  // Find the Positioned widget
  final positioned = tester.widget<Positioned>(find.byType(Positioned));
  expect(positioned.left, equals(0.0));
  expect(positioned.top, equals(0.0));
  expect(positioned.right, equals(0.0));
  expect(positioned.bottom, equals(0.0));
}
