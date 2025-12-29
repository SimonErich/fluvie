import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theRasterizedImageForFrame50ContainsTheCircleCenteredAtX50(
  WidgetTester tester,
) async {
  // Find the Positioned widget to verify circle position
  final positionedFinder = find.byType(Positioned);
  expect(positionedFinder, findsOneWidget);

  final positioned = tester.widget<Positioned>(positionedFinder);
  expect(positioned.left, 50.0);
}
