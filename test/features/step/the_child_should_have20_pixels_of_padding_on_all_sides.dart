import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the child should have 20 pixels of padding on all sides
Future<void> theChildShouldHave20PixelsOfPaddingOnAllSides(
    WidgetTester tester) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Find the Padding widget
  final padding = tester.widget<Padding>(find.byType(Padding));
  expect(padding.padding, equals(const EdgeInsets.all(20)));
}
