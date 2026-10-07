@Tags(['golden'])
library;

import 'dart:math' as math;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

const _rect = Rect.fromLTWH(60, 40, 120, 80);

Widget _stage({double rotation = 0, String? label, Offset? labelAnchor}) => OiThemeScope(
  data: OiThemeData.dark(),
  child: SizedBox(
    width: 240,
    height: 160,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF14141C)),
        Positioned.fromRect(
          rect: _rect,
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            child: const ColoredBox(color: Color(0xFF6C5CE7)),
          ),
        ),
        TransformGizmo(
          rect: _rect,
          rotation: rotation,
          viewport: CanvasViewportController(),
          label: label,
          labelAnchor: labelAnchor,
        ),
      ],
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'the gizmo frames its element in every state',
    fileName: 'transform_gizmo',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(name: 'selected', child: _stage()),
        GoldenTestScenario(name: 'rotated 30', child: _stage(rotation: 30)),
        GoldenTestScenario(
          name: 'resizing with dimensions',
          child: _stage(label: '384 × 256', labelAnchor: const Offset(180, 120)),
        ),
        GoldenTestScenario(
          name: 'rotating with angle',
          child: _stage(rotation: 45, label: '45°', labelAnchor: const Offset(180, 30)),
        ),
      ],
    ),
  );
}
