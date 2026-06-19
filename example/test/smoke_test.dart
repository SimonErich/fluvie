import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/main.dart';

void main() {
  testWidgets('the example app shell builds the inspector', (tester) async {
    // The inspector is a 3-column layout; give it a wide enough canvas so
    // the playback bar row doesn't overflow at the default 800 × 600.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FluvieExampleApp());
    await tester.pump(); // the preview's post-frame resolution pass

    expect(find.text('Fluvie inspector'), findsOneWidget);
    expect(find.text('Hello, video'), findsOneWidget);
  });
}
