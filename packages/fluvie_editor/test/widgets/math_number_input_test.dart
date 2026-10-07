import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

Future<List<double>> _pump(
  WidgetTester tester, {
  double value = 30,
  double? min,
  double? max,
}) async {
  final changes = <double>[];
  await tester.pumpWidget(
    OiThemeScope(
      data: OiThemeData.dark(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 160,
            height: 30,
            child: MathNumberInput(
              label: 'X',
              value: value,
              min: min,
              max: max,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  testWidgets('typing math commits the evaluated value', (tester) async {
    final changes = await _pump(tester);
    await tester.enterText(find.byType(EditableText), '+12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, [42]);
  });

  testWidgets('garbage reverts to the old value without a change', (tester) async {
    final changes = await _pump(tester);
    await tester.enterText(find.byType(EditableText), 'nope');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, isEmpty);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '30');
  });

  testWidgets('commits clamp into min and max', (tester) async {
    final changes = await _pump(tester, min: 0, max: 100);
    await tester.enterText(find.byType(EditableText), '400');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(changes, [100]);
  });

  testWidgets('arrow keys step, Shift steps by ten', (tester) async {
    final changes = await _pump(tester);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(changes, [31]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(changes, [31, 20]);
  });

  testWidgets('dragging the label scrubs the value', (tester) async {
    final changes = await _pump(tester);
    await tester.drag(find.text('X'), const Offset(25, 0));
    await tester.pump();
    expect(changes, isNotEmpty);
    expect(changes.last, greaterThan(30));
  });
}
