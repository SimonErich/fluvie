import 'package:flutter_test/flutter_test.dart';
import 'package:slides/start/start_actions.dart';

/// The start screen's affordances, named once. Copy on the screen changes
/// here and nowhere else.
///
/// Opens the samples dialog from the "MORE" list.
Future<void> openSamples(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Samples and tutorials'));
  await tester.tap(find.text('Samples and tutorials'));
  await tester.pumpAndSettle();
}

/// Opens the bundled demo spec on the canvas, through the samples dialog.
Future<void> openDemoForEdit(WidgetTester tester) async {
  await openSamples(tester);
  await tester.ensureVisible(find.text('Edit the demo deck'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit the demo deck'));
  await tester.pumpAndSettle();
}

/// Opens a `.fluvie` file in the editor (the injected picker supplies it).
///
/// The action column's button, not the recents header's ghost twin.
Future<void> openDeckForEdit(WidgetTester tester) async {
  final button = find.descendant(
    of: find.byType(StartActions),
    matching: find.text('Open a deck'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump();
}
