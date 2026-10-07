import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/colour/tone_curve_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  testWidgets('channel curve point edits, drag, removal and reset preserve other channels', (
    tester,
  ) async {
    var curves = <String, Object?>{};
    var commits = 0;
    await tester.pumpWidget(
      OiApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (_, setState) => ToneCurveEditor(
                curves: curves,
                onChanged: (next) {
                  commits++;
                  setState(() => curves = next);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add point'));
    await tester.pump();
    expect(curves['master'], [
      [0.0, 0.0],
      [0.5, 0.5],
      [1.0, 1.0],
    ]);
    tester.widget<MathNumberInput>(find.byKey(const ValueKey('curve-output'))).onChanged(.7);
    await tester.pump();
    tester.widget<MathNumberInput>(find.byKey(const ValueKey('curve-input'))).onChanged(.6);
    await tester.pump();
    expect(curves['master'], [
      [0.0, 0.0],
      [.6, .7],
      [1.0, 1.0],
    ]);
    final beforeDrag = commits;
    final plot = find.byKey(const ValueKey('curve-plot'));
    final rect = tester.getRect(plot);
    final drag = await tester.startGesture(
      Offset(rect.left + rect.width * .6, rect.top + rect.height * .3),
    );
    await drag.moveBy(const Offset(20, 10));
    await tester.pump();
    expect(commits, beforeDrag);
    await drag.moveBy(const Offset(10, 10));
    await drag.up();
    await tester.pump();
    expect(commits, beforeDrag + 1);
    final master = curves['master'];
    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('curve-channel'))).onChanged!('red');
    await tester.pump();
    await tester.tap(find.text('Add point'));
    await tester.pump();
    await tester.tap(find.text('Add point'));
    await tester.pump();
    expect(curves['red'], hasLength(4));
    tester.widget<OiSelect<int>>(find.byKey(const ValueKey('curve-point'))).onChanged!(2);
    await tester.pump();
    await tester.tap(find.text('Remove point'));
    await tester.pump();
    expect(curves['red'], hasLength(3));
    await tester.tap(find.text('Reset curve'));
    await tester.pump();
    expect(curves['red'], [
      [0.0, 0.0],
      [1.0, 1.0],
    ]);
    expect(curves['master'], master);
    expect(tester.takeException(), isNull);
  });
}
