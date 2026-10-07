import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Future<void> _pump(
  WidgetTester tester, {
  required String value,
  required ValueChanged<String> onChanged,
  int? maxLines = 1,
  String? placeholder,
}) async {
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 240,
          child: InspectorTextField(
            value: value,
            onChanged: onChanged,
            maxLines: maxLines,
            placeholder: placeholder,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a multi-line field keeps newlines and commits on focus loss', (tester) async {
    final commits = <String>[];
    await _pump(tester, value: '', onChanged: commits.add, maxLines: 4);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'line one\nline two');
    expect(tester.widget<EditableText>(find.byType(EditableText)).maxLines, 4);
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.unfocus();
    await tester.pump();
    expect(commits, ['line one\nline two']);
  });

  testWidgets('the placeholder shows while empty and hides once text lands', (tester) async {
    await _pump(tester, value: '', onChanged: (_) {}, placeholder: 'Type what to say');
    expect(find.text('Type what to say'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'notes');
    await tester.pump();
    expect(find.text('Type what to say'), findsNothing);
  });

  testWidgets('a non-empty value never shows the placeholder', (tester) async {
    await _pump(tester, value: 'already here', onChanged: (_) {}, placeholder: 'Type');
    expect(find.text('Type'), findsNothing);
  });

  testWidgets('a dropped commit snaps the field back to the committed value', (tester) async {
    // The owner refuses every commit (a colliding rename): after focus
    // loss the field must show the committed value again, not the lie.
    await _pump(tester, value: 'Alpha', onChanged: (_) {});
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Beta');
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.unfocus();
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Alpha');
  });

  testWidgets('an accepted commit keeps the new text', (tester) async {
    final commits = <String>[];
    await _pump(tester, value: 'Alpha', onChanged: commits.add);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Beta');
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.unfocus();
    await tester.pump();
    // The owner accepted: it rebuilds the field with the new value.
    await _pump(tester, value: 'Beta', onChanged: commits.add);
    await tester.pumpAndSettle();
    expect(commits, ['Beta']);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Beta');
  });
}
