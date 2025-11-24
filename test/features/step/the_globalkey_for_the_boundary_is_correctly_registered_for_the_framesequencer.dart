import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theGlobalkeyForTheBoundaryIsCorrectlyRegisteredForTheFramesequencer(
    WidgetTester tester) async {
  expect(find.byKey(const Key('video-boundary')), findsOneWidget);
}
