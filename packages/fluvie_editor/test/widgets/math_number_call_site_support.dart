import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show MathNumberInput;
import 'package:obers_ui/obers_ui.dart';

const callSiteMathViewport = Size(800, 600);
const ValueKey<String> callSiteMathParentKey = ValueKey('call-site-math-finite-parent');
const ValueKey<String> callSiteMathFieldKey = ValueKey('call-site-math-field');

/// Width-only parents reproduce callers without imposing a field height.
Widget callSiteMathApp(
  TextDirection direction,
  double width,
  List<double> changes, {
  required bool propertyGrid,
}) {
  var value = 123456.0;
  return OiApp(
    theme: OiThemeData.light(),
    density: OiDensity.compact,
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: direction,
      child: Center(
        child: SizedBox(
          key: callSiteMathParentKey,
          width: width,
          child: StatefulBuilder(
            builder: (context, setState) {
              final field = MathNumberInput(
                key: callSiteMathFieldKey,
                label: '',
                value: value,
                onChanged: (next) {
                  changes.add(next);
                  setState(() => value = next);
                },
              );
              if (!propertyGrid) return field;
              return OiPropertyGrid(
                dividerPosition: 0.7,
                properties: [OiPropertyRow(label: 'Value', editor: field)],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Full source value and actual viewports, not simultaneous numeric glyph fit.
void expectCallSiteMathLayout(
  WidgetTester tester,
  TextDirection direction,
  double width,
  String value,
) {
  final field = find.byKey(callSiteMathFieldKey);
  expect(field, findsOneWidget);
  final context = tester.element(field);
  expect(MediaQuery.sizeOf(context), callSiteMathViewport);
  expect(MediaQuery.devicePixelRatioOf(context), 1);
  expect(MediaQuery.textScalerOf(context).scale(16), 16);
  expect(Directionality.of(context), direction);
  expect(OiDensityScope.of(context), OiDensity.compact);
  final parentRect = tester.getRect(find.byKey(callSiteMathParentKey));
  expect(parentRect.width, width);
  _contained(parentRect, Offset.zero & callSiteMathViewport);
  final fieldRect = tester.getRect(field);
  _contained(fieldRect, parentRect);
  final editable = find.descendant(of: field, matching: find.byType(EditableText));
  expect(editable, findsOneWidget);
  final editorRect = tester.getRect(editable);
  _contained(editorRect, fieldRect);
  final editor = tester.widget<EditableText>(editable);
  expect(editor.controller.text, value);
  final rendered = tester.allRenderObjects.whereType<RenderEditable>().single;
  expect(rendered.text?.toPlainText(), value);
  expect(rendered.textScaler.scale(16), 16);
  final nativeViewport = rendered.localToGlobal(Offset.zero) & rendered.size;
  _contained(nativeViewport, editorRect);
  _contained(nativeViewport, fieldRect);
  _contained(nativeViewport, parentRect);
  final textFields = find.semantics.byFlag(SemanticsFlag.isTextField).evaluate().toList();
  expect(textFields, hasLength(1));
  expect(textFields.single.flagsCollection.isTextField, isTrue);
  expect(textFields.single.getSemanticsData().value, value);
}

/// Caret visibility is checked while editing, before done resets selection.
void expectCallSiteMathCaret(WidgetTester tester, String value) {
  final editable = find.byType(EditableText);
  final editor = tester.widget<EditableText>(editable);
  expect(editor.focusNode.hasFocus, isTrue);
  final selection = editor.controller.selection;
  expect(selection.isValid, isTrue);
  expect(selection.isCollapsed, isTrue);
  expect(selection.extentOffset, value.length);
  final rendered = tester.allRenderObjects.whereType<RenderEditable>().single;
  final caret = rendered.getLocalRectForCaret(selection.extent);
  final globalCaret = caret.shift(rendered.localToGlobal(Offset.zero));
  _contained(globalCaret, rendered.localToGlobal(Offset.zero) & rendered.size);
  _contained(globalCaret, tester.getRect(editable));
  _contained(globalCaret, tester.getRect(find.byKey(callSiteMathFieldKey)));
  _contained(globalCaret, tester.getRect(find.byKey(callSiteMathParentKey)));
}

void _contained(Rect bounds, Rect owner) {
  expect(bounds.isFinite, isTrue);
  expect(owner.isFinite, isTrue);
  expect(bounds.width, greaterThan(0));
  expect(bounds.height, greaterThan(0));
  expect(owner.width, greaterThan(0));
  expect(owner.height, greaterThan(0));
  expect(bounds.left, greaterThanOrEqualTo(owner.left));
  expect(bounds.top, greaterThanOrEqualTo(owner.top));
  expect(bounds.right, lessThanOrEqualTo(owner.right));
  expect(bounds.bottom, lessThanOrEqualTo(owner.bottom));
}
