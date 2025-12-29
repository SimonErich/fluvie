import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the child should have vertical padding of 20
Future<void> theChildShouldHaveVerticalPaddingOf20(WidgetTester tester) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Find the Padding widget
  final padding = tester.widget<Padding>(find.byType(Padding));
  final edgeInsets = padding.padding as EdgeInsets;
  expect(edgeInsets.top, equals(20));
  expect(edgeInsets.bottom, equals(20));
}
