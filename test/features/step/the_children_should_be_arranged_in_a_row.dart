import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the children should be arranged in a Row
Future<void> theChildrenShouldBeArrangedInARow(WidgetTester tester) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Verify that a Row widget exists
  expect(find.byType(Row), findsOneWidget);

  // Verify all three children are present
  expect(find.byKey(const Key('child1')), findsOneWidget);
  expect(find.byKey(const Key('child2')), findsOneWidget);
  expect(find.byKey(const Key('child3')), findsOneWidget);
}
