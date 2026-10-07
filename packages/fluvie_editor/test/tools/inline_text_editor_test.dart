import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/src/tools/inline_text_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

Future<(List<String>, List<int>)> _pump(WidgetTester tester) async {
  final commits = <String>[];
  final cancels = <int>[];
  await tester.pumpWidget(
    OiThemeScope(
      data: OiThemeData.dark(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 40,
            child: InlineTextEditor(
              initialText: 'Hello',
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
              onCommit: commits.add,
              onCancel: () => cancels.add(1),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (commits, cancels);
}

void main() {
  testWidgets('Enter commits the edited text exactly once', (tester) async {
    final (commits, cancels) = await _pump(tester);
    await tester.enterText(find.byType(EditableText), 'Changed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(commits, ['Changed']);
    expect(cancels, isEmpty);

    // A later focus loss must not double-commit.
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.unfocus();
    await tester.pump();
    expect(commits, hasLength(1));
  });

  testWidgets('Escape cancels without committing', (tester) async {
    final (commits, cancels) = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(cancels, hasLength(1));
    expect(commits, isEmpty);
  });

  testWidgets('losing focus commits the current text', (tester) async {
    final (commits, _) = await _pump(tester);
    await tester.enterText(find.byType(EditableText), 'Blurred');
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.unfocus();
    await tester.pump();
    expect(commits, ['Blurred']);
  });
}
