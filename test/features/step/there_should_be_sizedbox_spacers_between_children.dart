import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layout_context.dart';

/// Usage: there should be SizedBox spacers between children
Future<void> thereShouldBeSizedboxSpacersBetweenChildren(
  WidgetTester tester,
) async {
  final widget = getCurrentWidget();
  await tester.pumpWidget(MaterialApp(home: widget));

  // Find all SizedBox widgets (spacers)
  final sizedBoxes = find.byType(SizedBox);

  // There should be at least one SizedBox (the spacer between children)
  expect(sizedBoxes, findsWidgets);

  // Check that the SizedBox has the correct width
  final sizedBox = tester.widget<SizedBox>(sizedBoxes.first);
  expect(sizedBox.width, equals(20));
}
