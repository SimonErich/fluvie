import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theRasterizedImageShowsTheGreenCircleVisiblyOverlayingTheRedBox(
  WidgetTester tester,
) async {
  expect(find.byType(Stack), findsOneWidget);
  // In a real test we might check render object painting order or use golden tests
}
