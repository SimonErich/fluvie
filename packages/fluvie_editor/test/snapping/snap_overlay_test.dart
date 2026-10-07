import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

const _edge = SnapLine(kind: SnapKind.edge, orientation: SnapOrientation.vertical, position: 100);
const _center = SnapLine(
  kind: SnapKind.center,
  orientation: SnapOrientation.horizontal,
  position: 80,
);

Widget _stage(List<SnapLine> lines) => OiThemeScope(
  data: OiThemeData.dark(),
  child: SizedBox(
    width: 240,
    height: 160,
    child: SnapGuideOverlay(lines: lines, viewport: CanvasViewportController()),
  ),
);

void main() {
  testWidgets('mounting with lines pulses once and settles', (tester) async {
    await tester.pumpWidget(_stage(const [_edge]));
    expect(tester.hasRunningAnimations, isTrue, reason: 'a fresh snap pulses');
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isFalse, reason: 'the pulse is brief');
  });

  testWidgets('the same lines never restart the pulse; a new one does', (tester) async {
    await tester.pumpWidget(_stage(const [_edge]));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(_stage(const [_edge]));
    expect(tester.hasRunningAnimations, isFalse, reason: 'nothing new to announce');

    await tester.pumpWidget(_stage(const [_edge, _center]));
    expect(tester.hasRunningAnimations, isTrue, reason: 'a new snap pulses again');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('no lines, no pulse', (tester) async {
    await tester.pumpWidget(_stage(const []));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
