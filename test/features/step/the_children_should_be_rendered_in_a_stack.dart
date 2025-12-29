import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the children should be rendered in a Stack
Future<void> theChildrenShouldBeRenderedInAStack(WidgetTester tester) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Verify that a Stack widget exists
  expect(find.byType(Stack), findsOneWidget);

  // Verify both children are present
  expect(find.byKey(const Key('child1')), findsOneWidget);
  expect(find.byKey(const Key('child2')), findsOneWidget);
}
