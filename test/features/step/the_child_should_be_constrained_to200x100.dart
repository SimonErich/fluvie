import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the child should be constrained to 200x100
Future<void> theChildShouldBeConstrainedTo200x100(WidgetTester tester) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Find the SizedBox widget
  final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
  expect(sizedBox.width, equals(200));
  expect(sizedBox.height, equals(100));
}
