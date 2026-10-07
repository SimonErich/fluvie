@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

Widget _picker(Color color) => OiThemeScope(
  data: OiThemeData.dark(),
  child: SizedBox(
    width: 220,
    child: SpectrumColorPicker(
      color: color,
      palette: const [Color(0xFF6C5CE7), Color(0xFF2ECC8F), Color(0xFFF0D86A)],
      onChanged: (_) {},
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'the spectrum picker shows area, sliders, hex, and palette',
    fileName: 'spectrum_color_picker',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(name: 'saturated red', child: _picker(const Color(0xFFFF0000))),
        GoldenTestScenario(name: 'half-alpha teal', child: _picker(const Color(0x8020B2AA))),
      ],
    ),
  );
}
