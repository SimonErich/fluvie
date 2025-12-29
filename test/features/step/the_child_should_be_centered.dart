import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the child should be centered
Future<void> theChildShouldBeCentered(WidgetTester tester) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Verify that a Center widget exists
  expect(find.byType(Center), findsOneWidget);

  // Verify the child is present
  expect(find.byKey(const Key('child')), findsOneWidget);
}
