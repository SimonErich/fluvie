import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: the child should be constrained to 150x150
Future<void> theChildShouldBeConstrainedTo150x150(WidgetTester tester) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Find the SizedBox widget
  final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
  expect(sizedBox.width, equals(150));
  expect(sizedBox.height, equals(150));
}
