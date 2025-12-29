import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the children should be arranged in a Column
Future<void> theChildrenShouldBeArrangedInAColumn(WidgetTester tester) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Verify that a Column widget exists
  expect(find.byType(Column), findsOneWidget);

  // Verify all three children are present
  expect(find.byKey(const Key('child1')), findsOneWidget);
  expect(find.byKey(const Key('child2')), findsOneWidget);
  expect(find.byKey(const Key('child3')), findsOneWidget);
}
