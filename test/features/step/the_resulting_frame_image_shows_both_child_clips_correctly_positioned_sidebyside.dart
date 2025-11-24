import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theResultingFrameImageShowsBothChildClipsCorrectlyPositionedSidebyside(
    WidgetTester tester) async {
  expect(find.byType(Row), findsOneWidget);
}
