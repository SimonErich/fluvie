import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show HistoryKeys, InspectorTextField;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

final class _Counts {
  int undone = 0;
  int redone = 0;
}

Future<_Counts> _pump(
  WidgetTester tester, {
  bool canUndo = true,
  bool canRedo = true,
  Widget? child,
}) async {
  final counts = _Counts();
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: HistoryKeys(
        canUndo: canUndo,
        canRedo: canRedo,
        onUndo: () => counts.undone++,
        onRedo: () => counts.redone++,
        child: child ?? const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ),
  );
  await tester.pump();
  return counts;
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = true,
  bool shift = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('Ctrl+Z undoes from any focused descendant', (tester) async {
    final counts = await _pump(tester);
    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(counts.undone, 1);
    expect(counts.redone, 0);
  });

  testWidgets('Ctrl+Shift+Z and Ctrl+Y both redo', (tester) async {
    final counts = await _pump(tester);
    await _chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(counts.redone, 1);
    await _chord(tester, LogicalKeyboardKey.keyY);
    expect(counts.redone, 2);
    expect(counts.undone, 0);
  });

  testWidgets('a disabled step reads as ignored', (tester) async {
    final counts = await _pump(tester, canUndo: false, canRedo: false);
    await _chord(tester, LogicalKeyboardKey.keyZ);
    await _chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(counts.undone, 0);
    expect(counts.redone, 0);
  });

  testWidgets('a bare Z stays out of the history', (tester) async {
    final counts = await _pump(tester);
    await _chord(tester, LogicalKeyboardKey.keyZ, control: false);
    expect(counts.undone, 0);
  });

  testWidgets('a focused text field keeps its own undo', (tester) async {
    final counts = await _pump(
      tester,
      child: InspectorTextField(value: 'hello', onChanged: (_) {}),
    );
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(counts.undone, 0);
  });
}
