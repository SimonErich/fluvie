@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

GradientEditorValue _threeStop({GradientEditorKind kind = GradientEditorKind.linear}) =>
    GradientEditorValue(
      stops: const [
        GradientEditorStop(offset: 0, color: Color(0xFF101018)),
        GradientEditorStop(offset: 0.5, color: Color(0xFF6C5CE7)),
        GradientEditorStop(offset: 1, color: Color(0xFF2EFF9A)),
      ],
      kind: kind,
    );

Widget _editor(GradientEditorValue value) => OiThemeScope(
  data: OiThemeData.dark(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      // Tight in both dimensions: OiPropertyGrid's LayoutBuilder cannot
      // answer the golden table's intrinsic queries.
      width: 240,
      height: 190,
      child: GradientEditor(
        value: value,
        onChanged: (_) {},
        stopColorEditor: (context, index, stop) => ColorField(
          label: 'Stop color',
          color: stop.color,
          onChanged: (_) {},
        ),
      ),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'the gradient editor shows the stops bar, angle, and kind',
    fileName: 'gradient_editor',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(
          name: 'linear, three stops, first selected',
          child: _editor(_threeStop()),
        ),
        GoldenTestScenario(
          name: 'radial hides the angle',
          child: _editor(_threeStop(kind: GradientEditorKind.radial)),
        ),
      ],
    ),
  );
}
