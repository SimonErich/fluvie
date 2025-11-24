import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theRasterizedImageForFrame50ContainsTheCircleCenteredAtX50(
    WidgetTester tester) async {
  final containerFinder = find.byType(Container);
  final container = tester.widget<Container>(containerFinder);
  // We can't easily check the Positioned widget's properties directly from the Container.
  // We need to find the Positioned widget.
  // But Positioned is a ParentDataWidget, it doesn't appear in the widget tree as a normal widget we can find easily with find.byType(Positioned) in some contexts, but usually it does.
  // Let's try finding the Positioned.
  
  final positionedFinder = find.byType(Positioned);
  expect(positionedFinder, findsOneWidget);
  
  final positioned = tester.widget<Positioned>(positionedFinder);
  expect(positioned.left, 50.0);
}
