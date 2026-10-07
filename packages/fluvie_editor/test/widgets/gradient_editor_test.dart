import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _red = Color(0xFFFF0000);

GradientEditorValue _twoStop({GradientEditorKind kind = GradientEditorKind.linear}) =>
    GradientEditorValue(
      stops: const [
        GradientEditorStop(offset: 0, color: _black),
        GradientEditorStop(offset: 1, color: _white),
      ],
      kind: kind,
    );

GradientEditorValue _threeStop() => const GradientEditorValue(
  stops: [
    GradientEditorStop(offset: 0, color: _black),
    GradientEditorStop(offset: 0.5, color: _red),
    GradientEditorStop(offset: 1, color: _white),
  ],
);

final class _Editing {
  final List<GradientEditorValue> changes = [];
  final List<int> editedIndexes = [];
}

Future<_Editing> _pump(
  WidgetTester tester,
  GradientEditorValue value, {
  bool showKind = true,
}) async {
  final editing = _Editing();
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: Center(
        child: SizedBox(
          width: 216,
          child: GradientEditor(
            value: value,
            showKind: showKind,
            onChanged: editing.changes.add,
            stopColorEditor: (context, index, stop) {
              editing.editedIndexes.add(index);
              return Text('edit-$index', key: ValueKey('editor-$index'));
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return editing;
}

/// The bar's position for [fraction], following the 8px handle inset.
Offset _barAt(WidgetTester tester, double fraction) {
  final bar = tester.getRect(find.byKey(const ValueKey('gradient-stops-bar')));
  return Offset(bar.left + 8 + (bar.width - 16) * fraction, bar.center.dy);
}

void main() {
  testWidgets('renders one handle per stop and selects the first', (tester) async {
    final editing = await _pump(tester, _threeStop());
    expect(find.byKey(const ValueKey('gradient-stop-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('gradient-stop-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('gradient-stop-2')), findsOneWidget);
    expect(editing.editedIndexes.last, 0, reason: 'the first stop starts selected');
  });

  testWidgets('tapping a handle selects its stop without a change', (tester) async {
    final editing = await _pump(tester, _threeStop());
    await tester.tapAt(_barAt(tester, 0.5));
    await tester.pump();
    expect(editing.changes, isEmpty);
    expect(editing.editedIndexes.last, 1);
  });

  testWidgets('tapping empty bar adds an interpolated stop there', (tester) async {
    final editing = await _pump(tester, _twoStop());
    await tester.tapAt(_barAt(tester, 0.75));
    await tester.pump();
    final added = editing.changes.single;
    expect(added.stops, hasLength(3));
    expect(added.stops[1].offset, closeTo(0.75, 0.03));
    expect(added.stops[1].color.r, closeTo(0.75, 0.05));
  });

  testWidgets('dragging a handle moves its stop, one change on release', (tester) async {
    final editing = await _pump(tester, _threeStop());
    final gesture = await tester.startGesture(_barAt(tester, 0.5));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(editing.changes, isEmpty, reason: 'a drag commits once, on release');
    await gesture.up();
    await tester.pump();
    expect(editing.changes.single.stops[1].offset, closeTo(0.75, 0.03));
  });

  testWidgets('dragging a handle off the bar removes its stop', (tester) async {
    final editing = await _pump(tester, _threeStop());
    final gesture = await tester.startGesture(_barAt(tester, 0.5));
    await gesture.moveBy(const Offset(0, 48));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(editing.changes.single.stops, hasLength(2));
    expect([for (final stop in editing.changes.single.stops) stop.color], [_black, _white]);
  });

  testWidgets('two stops never drop below two', (tester) async {
    final editing = await _pump(tester, _twoStop());
    final gesture = await tester.startGesture(_barAt(tester, 0));
    await gesture.moveBy(const Offset(0, 48));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(editing.changes, isEmpty);
  });

  testWidgets('the kind select flips to radial and hides the angle', (tester) async {
    final editing = await _pump(tester, _twoStop());
    expect(find.text('Angle'), findsOneWidget);
    await tester.tap(find.byType(OiSelect<GradientEditorKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('radial').last);
    await tester.pumpAndSettle();
    expect(editing.changes.single.kind, GradientEditorKind.radial);

    await _pump(tester, _twoStop(kind: GradientEditorKind.radial));
    expect(find.text('Angle'), findsNothing);
  });

  testWidgets('showKind false hides the kind select', (tester) async {
    await _pump(tester, _twoStop(), showKind: false);
    expect(find.byType(OiSelect<GradientEditorKind>), findsNothing);
  });

  testWidgets('the angle field writes degrees normalized to 0..360', (tester) async {
    final editing = await _pump(tester, _twoStop());
    await tester.enterText(find.byType(EditableText).last, '450');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(editing.changes.single.angle, 90);
  });

  testWidgets('an added stop keeps its tapped offset (no redistribution)', (tester) async {
    final editing = await _pump(tester, _twoStop());
    await tester.tapAt(_barAt(tester, 0.8));
    await tester.pump();
    expect(editing.changes.single.stops[1].offset, closeTo(0.8, 0.03));
    expect(editing.changes.single.stops.first.offset, 0);
    expect(editing.changes.single.stops.last.offset, 1);
  });

  testWidgets('a removal leaves the surviving offsets untouched', (tester) async {
    final editing = await _pump(tester, _threeStop());
    final gesture = await tester.startGesture(_barAt(tester, 0.5));
    await gesture.moveBy(const Offset(0, 48));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect([for (final stop in editing.changes.single.stops) stop.offset], [0, 1]);
  });

  testWidgets('a drag from empty bar space changes nothing', (tester) async {
    final editing = await _pump(tester, _twoStop());
    final gesture = await tester.startGesture(_barAt(tester, 0.5));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(editing.changes, isEmpty);
  });

  testWidgets('the selected stop edits through the injected color editor', (tester) async {
    final editing = await _pump(tester, _threeStop());
    await tester.tapAt(_barAt(tester, 0.5));
    await tester.pump();
    expect(find.byKey(const ValueKey('editor-1')), findsOneWidget);
    expect(editing.changes, isEmpty);
  });
}
