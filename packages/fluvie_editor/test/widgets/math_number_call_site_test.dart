import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show MathNumberInput;

import 'math_number_call_site_support.dart';

void main() {
  for (final scenario in [
    (
      direction: TextDirection.ltr,
      width: 56.0,
      grid: false,
      name: 'blank Math width56 LTR retains scrolling, native caret and commit',
    ),
    (
      direction: TextDirection.rtl,
      width: 56.0,
      grid: false,
      name: 'blank Math width56 RTL retains scrolling, native caret and commit',
    ),
    (
      direction: TextDirection.ltr,
      width: 72.0,
      grid: false,
      name: 'blank Math width72 LTR retains scrolling, native caret and commit',
    ),
    (
      direction: TextDirection.rtl,
      width: 72.0,
      grid: false,
      name: 'blank Math width72 RTL retains scrolling, native caret and commit',
    ),
    (
      direction: TextDirection.ltr,
      width: 240.0,
      grid: true,
      name: 'blank Math property grid LTR retains scrolling, native caret and commit',
    ),
    (
      direction: TextDirection.rtl,
      width: 240.0,
      grid: true,
      name: 'blank Math property grid RTL retains scrolling, native caret and commit',
    ),
  ]) {
    testWidgets(scenario.name, (tester) async {
      final changes = <double>[];
      final previousPlatform = debugDefaultTargetPlatformOverride;
      final semantics = tester.ensureSemantics();
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = callSiteMathViewport;
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      try {
        await tester.binding.setSurfaceSize(callSiteMathViewport);
        await tester.pumpWidget(
          callSiteMathApp(
            scenario.direction,
            scenario.width,
            changes,
            propertyGrid: scenario.grid,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectCallSiteMathLayout(tester, scenario.direction, scenario.width, '123456');
        expect(changes, isEmpty);
        final editable = find.byType(EditableText);

        await tester.tap(editable, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
        expect(tester.takeException(), isNull);

        await tester.enterText(editable, '765432');
        await tester.pumpAndSettle();
        expectCallSiteMathLayout(tester, scenario.direction, scenario.width, '765432');
        expectCallSiteMathCaret(tester, '765432');
        expect(changes, isEmpty);
        expect(tester.takeException(), isNull);

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(changes, [765432]);
        expect(tester.widget<MathNumberInput>(find.byKey(callSiteMathFieldKey)).value, 765432);
        expectCallSiteMathLayout(tester, scenario.direction, scenario.width, '765432');
        expect(tester.takeException(), isNull);
      } finally {
        final beforeUnmount = List<double>.of(changes);
        try {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(find.byKey(callSiteMathFieldKey), findsNothing);
          expect(changes, beforeUnmount);
          expect(tester.takeException(), isNull);
        } finally {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          try {
            await tester.binding.setSurfaceSize(null);
          } finally {
            debugDefaultTargetPlatformOverride = previousPlatform;
            semantics.dispose();
          }
        }
      }
    });
  }
}
