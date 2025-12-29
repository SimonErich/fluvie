import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the child should have horizontal padding of 10
Future<void> theChildShouldHaveHorizontalPaddingOf10(
  WidgetTester tester,
) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Find the Padding widget
  final padding = tester.widget<Padding>(find.byType(Padding));
  final edgeInsets = padding.padding as EdgeInsets;
  expect(edgeInsets.left, equals(10));
  expect(edgeInsets.right, equals(10));
}
