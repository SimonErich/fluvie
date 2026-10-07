@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

/// The snap chrome, pixel-pinned: the smart-guide lines must run exactly
/// along the boxes they snapped (an edge line kisses both edges, a center
/// line cuts both centers), and the rulers must frame the stage with a
/// guide where its fraction says.
Widget _frame(Widget child) => OiThemeScope(
  data: OiThemeData.dark(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 240, height: 160, child: child),
  ),
);

/// A drag mid-snap: the moving box's left edge sits on the candidate's
/// right edge (x 100) and both centers align at y 80.
Widget _snapStage() => _frame(
  Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Color(0xFF14141C)),
      Positioned.fromRect(
        rect: const Rect.fromLTWH(40, 30, 60, 100),
        child: const ColoredBox(color: Color(0xFF2ECC8F)),
      ),
      Positioned.fromRect(
        rect: const Rect.fromLTWH(100, 55, 70, 50),
        child: const ColoredBox(color: Color(0xFF6C5CE7)),
      ),
      SnapGuideOverlay(
        lines: const [
          SnapLine(kind: SnapKind.edge, orientation: SnapOrientation.vertical, position: 100),
          SnapLine(kind: SnapKind.center, orientation: SnapOrientation.horizontal, position: 80),
        ],
        viewport: CanvasViewportController(),
      ),
    ],
  ),
);

/// The rulers with one manual guide at half the slide width (x 120).
Widget _rulerStage() => _frame(
  Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Color(0xFF14141C)),
      Positioned.fromRect(
        rect: const Rect.fromLTWH(60, 60, 80, 60),
        child: const ColoredBox(color: Color(0xFF6C5CE7)),
      ),
      GuideLayer(
        viewport: CanvasViewportController(),
        slideSize: const Size(240, 160),
        guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.5)],
        onGuidesChanged: (_) {},
      ),
    ],
  ),
);

Future<void> main() async {
  await goldenTest(
    'the snap chrome sits exactly on what it snapped',
    fileName: 'snap_overlay',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(name: 'edge and center snap during a drag', child: _snapStage()),
        GoldenTestScenario(name: 'rulers and a manual guide', child: _rulerStage()),
      ],
    ),
  );
}
