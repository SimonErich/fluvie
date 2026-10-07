import 'package:flutter/widgets.dart' show Alignment, Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Placement;
import 'package:fluvie_editor/fluvie_editor.dart';

const _canvas = Size(1000, 500);

/// A sized element: placement (0.2, 0.2, w 0.2, h 0.2) lays out at
/// LTWH(100, 50, 200, 100) on the 1000x500 canvas.
const ({Placement placement, Rect rect}) _sized = (
  rect: Rect.fromLTWH(100, 50, 200, 100),
  placement: Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
);

void _expectPlacement(
  Placement actual,
  Placement expected, {
  double tolerance = 1e-9,
}) {
  expect(actual.x, closeTo(expected.x, tolerance));
  expect(actual.y, closeTo(expected.y, tolerance));
  if (expected.width == null) {
    expect(actual.width, isNull);
  } else {
    expect(actual.width, isNotNull);
    expect(actual.width, closeTo(expected.width!, tolerance));
  }
  if (expected.height == null) {
    expect(actual.height, isNull);
  } else {
    expect(actual.height, isNotNull);
    expect(actual.height, closeTo(expected.height!, tolerance));
  }
  expect(actual.rotation, closeTo(expected.rotation, tolerance));
  expect(actual.anchor, expected.anchor);
}

void main() {
  group('move', () {
    test('shifts the placement by the pointer delta, in fractions', () {
      final drag = TransformDrag.move(
        targets: const {'el-a': _sized},
        canvas: _canvas,
        origin: const Offset(150, 80),
      );
      final placements = drag.update(const Offset(250, 130));
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.3, y: 0.3, width: 0.2, height: 0.2),
      );
    });

    test('an intrinsic element moves and stays intrinsic', () {
      final drag = TransformDrag.move(
        targets: const {
          'el-i': (
            rect: Rect.fromLTWH(450, 225, 100, 50),
            placement: Placement(x: 0.5, y: 0.5),
          ),
        },
        canvas: _canvas,
        origin: Offset.zero,
      );
      final placements = drag.update(const Offset(10, -25));
      _expectPlacement(placements['el-i']!, const Placement(x: 0.51, y: 0.45));
    });

    test('a non-center anchor is preserved and lands correctly', () {
      final drag = TransformDrag.move(
        targets: const {
          'el-t': (
            rect: Rect.fromLTWH(100, 50, 200, 100),
            placement: Placement(
              x: 0.1,
              y: 0.1,
              width: 0.2,
              height: 0.2,
              anchor: Alignment.topLeft,
            ),
          ),
        },
        canvas: _canvas,
        origin: Offset.zero,
      );
      final placements = drag.update(const Offset(100, 50));
      _expectPlacement(
        placements['el-t']!,
        const Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2, anchor: Alignment.topLeft),
      );
    });

    test('a multi-selection moves as one', () {
      final drag = TransformDrag.move(
        targets: const {
          'el-a': _sized,
          'el-i': (
            rect: Rect.fromLTWH(450, 225, 100, 50),
            placement: Placement(x: 0.5, y: 0.5),
          ),
        },
        canvas: _canvas,
        origin: Offset.zero,
      );
      final placements = drag.update(const Offset(100, 50));
      expect(placements, hasLength(2));
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.3, y: 0.3, width: 0.2, height: 0.2),
      );
      _expectPlacement(placements['el-i']!, const Placement(x: 0.6, y: 0.6));
    });

    test('rotation rides along untouched', () {
      final drag = TransformDrag.move(
        targets: const {
          'el-r': (
            rect: Rect.fromLTWH(100, 50, 200, 100),
            placement: Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2, rotation: 30),
          ),
        },
        canvas: _canvas,
        origin: Offset.zero,
      );
      final placements = drag.update(const Offset(100, 50));
      expect(placements['el-r']!.rotation, 30);
    });
  });

  group('resize', () {
    TransformDrag corner({GizmoHandle handle = GizmoHandle.bottomRight}) => TransformDrag.resize(
      id: 'el-a',
      target: _sized,
      canvas: _canvas,
      handle: handle,
    );

    test('a corner handle resizes both axes around the opposite corner', () {
      final placements = corner().update(const Offset(350, 250));
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.225, y: 0.3, width: 0.25, height: 0.4),
      );
    });

    test('a side handle resizes one axis only', () {
      final placements = corner(handle: GizmoHandle.right).update(const Offset(350, 999));
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.225, y: 0.2, width: 0.25, height: 0.2),
      );
    });

    test('Shift keeps the aspect ratio, following the dominant axis', () {
      final placements = corner().update(const Offset(350, 250), aspect: true);
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
      );
    });

    test('Alt resizes around the center', () {
      final placements = corner().update(const Offset(350, 250), fromCenter: true);
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.2, y: 0.2, width: 0.3, height: 0.6),
      );
    });

    test('a rotated element resizes in its own axes, opposite corner pinned', () {
      final drag = TransformDrag.resize(
        id: 'el-a',
        target: (
          rect: const Rect.fromLTWH(100, 50, 200, 100),
          placement: const Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2, rotation: 90),
        ),
        canvas: _canvas,
        handle: GizmoHandle.bottomRight,
      );
      final placements = drag.update(const Offset(150, 220));
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.2, y: 0.22, width: 0.22, height: 0.2, rotation: 90),
      );
    });

    test('the size clamps at the minimum instead of flipping', () {
      final placements = corner().update(const Offset(90, 40));
      final placement = placements['el-a']!;
      expect(placement.width! * _canvas.width, 1);
      expect(placement.height! * _canvas.height, 1);
      expect(placement.x, closeTo(0.1005, 1e-9));
      expect(placement.y, closeTo(0.101, 1e-9));
    });
  });

  group('rotate', () {
    TransformDrag rotate({
      Placement placement = const Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
    }) => TransformDrag.rotate(
      id: 'el-a',
      target: (rect: _sized.rect, placement: placement),
      origin: const Offset(300, 100),
    );

    test('the rotation follows the pointer angle around the center', () {
      final placements = rotate().update(const Offset(300, 200));
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2, rotation: 45),
      );
    });

    test('Shift snaps to 15-degree steps', () {
      final free = rotate().update(const Offset(300, 190));
      expect(free['el-a']!.rotation, closeTo(41.987, 0.01));
      final snapped = rotate().update(const Offset(300, 190), snap: true);
      expect(snapped['el-a']!.rotation, 45);
    });

    test('the angle normalizes around zero', () {
      final placements = rotate(
        placement: const Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2, rotation: 170),
      ).update(const Offset(200, 200));
      expect(placements['el-a']!.rotation, -100);
    });

    test('position and size never change while rotating', () {
      final placements = rotate().update(const Offset(240, 180));
      final placement = placements['el-a']!;
      expect(placement.x, 0.2);
      expect(placement.y, 0.2);
      expect(placement.width, 0.2);
      expect(placement.height, 0.2);
    });
  });
  aspectSideSuite();
  snapSuite();
}

// The engine riding inside the drag: moves adjust by the selection's
// bounding rect, resizes by the dragged edge alone, and the bypass modifier
// switches it all off per update.
void snapSuite() {
  SnapEngine engine({List<Rect> candidates = const []}) =>
      SnapEngine(slide: _canvas, candidates: candidates);

  group('move with a snapper', () {
    test('the dragged rect lands on a nearby edge and reports the line', () {
      final drag = TransformDrag.move(
        targets: const {'el-a': _sized},
        canvas: _canvas,
        origin: const Offset(150, 80),
        snapper: engine(candidates: const [Rect.fromLTWH(304, 300, 100, 100)]),
      );
      // Delta +2 puts the right edge at 302, 2px short of the candidate.
      final placements = drag.update(const Offset(152, 80));
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.204, y: 0.2, width: 0.2, height: 0.2),
      );
      expect(drag.activeSnapLines, const [
        SnapLine(kind: SnapKind.edge, orientation: SnapOrientation.vertical, position: 304),
      ]);
    });

    test('the bypass modifier disables the snap for a fine nudge', () {
      final drag = TransformDrag.move(
        targets: const {'el-a': _sized},
        canvas: _canvas,
        origin: const Offset(150, 80),
        snapper: engine(candidates: const [Rect.fromLTWH(304, 300, 100, 100)]),
      );
      final placements = drag.update(const Offset(152, 80), bypassSnap: true);
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.202, y: 0.2, width: 0.2, height: 0.2),
      );
      expect(drag.activeSnapLines, isEmpty);
    });

    test('a multi-selection snaps by its combined bounding rect', () {
      final drag = TransformDrag.move(
        targets: const {
          'el-a': _sized,
          'el-b': (
            rect: Rect.fromLTWH(400, 300, 50, 50),
            placement: Placement(x: 0.425, y: 0.65, width: 0.05, height: 0.1),
          ),
        },
        canvas: _canvas,
        origin: Offset.zero,
        snapper: engine(candidates: const [Rect.fromLTWH(452, 60, 100, 100)]),
      );
      // The union's right edge (450) sits 2px from the candidate: both
      // elements shift together.
      final placements = drag.update(Offset.zero);
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.202, y: 0.2, width: 0.2, height: 0.2),
      );
      _expectPlacement(
        placements['el-b']!,
        const Placement(x: 0.427, y: 0.65, width: 0.05, height: 0.1),
      );
    });
  });

  group('resize with a snapper', () {
    TransformDrag resize({SnapEngine? snapper, Placement? placement, double minSize = 1}) =>
        TransformDrag.resize(
          id: 'el-a',
          target: (rect: _sized.rect, placement: placement ?? _sized.placement),
          canvas: _canvas,
          handle: GizmoHandle.right,
          minSize: minSize,
          snapper: snapper,
        );

    test('the dragged edge snaps; the pinned edge stays', () {
      final drag = resize(snapper: engine(candidates: const [Rect.fromLTWH(304, 300, 100, 100)]));
      final placements = drag.update(const Offset(302, 100));
      _expectPlacement(
        placements['el-a']!,
        const Placement(x: 0.202, y: 0.2, width: 0.204, height: 0.2),
      );
      expect(drag.activeSnapLines, const [
        SnapLine(kind: SnapKind.edge, orientation: SnapOrientation.vertical, position: 304),
      ]);
    });

    test('the bypass modifier disables the resize snap', () {
      final drag = resize(snapper: engine(candidates: const [Rect.fromLTWH(304, 300, 100, 100)]));
      final placements = drag.update(const Offset(302, 100), bypassSnap: true);
      expect(placements['el-a']!.width, closeTo(0.202, 1e-9));
      expect(drag.activeSnapLines, isEmpty);
    });

    test('an aspect-locked resize never snaps', () {
      final drag = resize(snapper: engine(candidates: const [Rect.fromLTWH(304, 300, 100, 100)]));
      final placements = drag.update(const Offset(302, 100), aspect: true);
      expect(placements['el-a']!.width, closeTo(0.202, 1e-9));
      expect(drag.activeSnapLines, isEmpty);
    });

    test('a from-center resize never snaps', () {
      final drag = resize(snapper: engine(candidates: const [Rect.fromLTWH(304, 300, 100, 100)]));
      // From the center (200), the pointer at 301 doubles to width 202 and
      // puts the right edge at 301, 3px from the candidate: still no snap.
      final placements = drag.update(const Offset(301, 100), fromCenter: true);
      expect(placements['el-a']!.width, closeTo(0.202, 1e-9));
      expect(drag.activeSnapLines, isEmpty);
    });

    test('a rotated element never snaps on resize', () {
      final drag = resize(
        snapper: engine(candidates: const [Rect.fromLTWH(304, 300, 100, 100)]),
        placement: const Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2, rotation: 30),
      )..update(const Offset(302, 100));
      expect(drag.activeSnapLines, isEmpty);
    });

    test('a snap that would shrink below the minimum size is dropped', () {
      final drag = resize(
        snapper: engine(candidates: const [Rect.fromLTWH(295, 300, 100, 100)]),
        minSize: 200,
      );
      // The pointer asks for width 197, clamped to 200 (right edge 300);
      // snapping onto 295 would shrink to 195, so the snap is refused.
      final placements = drag.update(const Offset(297, 100));
      expect(placements['el-a']!.width, closeTo(0.2, 1e-9));
      expect(drag.activeSnapLines, isEmpty);
    });
  });
}

// Aspect on side handles: the changing axis drives the other.
void aspectSideSuite() {
  test('Shift on a side handle scales both axes from the dragged one', () {
    final wide = TransformDrag.resize(
      id: 'el-a',
      target: (
        rect: const Rect.fromLTWH(100, 50, 200, 100),
        placement: const Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
      ),
      canvas: const Size(1000, 500),
      handle: GizmoHandle.right,
    ).update(const Offset(400, 90), aspect: true);
    final placement = wide['el-a']!;
    // Width 300 (3/2 of 200) drives height to 150.
    expect(placement.width, closeTo(0.3, 1e-9));
    expect(placement.height, closeTo(0.3, 1e-9));

    final tall = TransformDrag.resize(
      id: 'el-a',
      target: (
        rect: const Rect.fromLTWH(100, 50, 200, 100),
        placement: const Placement(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
      ),
      canvas: const Size(1000, 500),
      handle: GizmoHandle.bottom,
    ).update(const Offset(200, 200), aspect: true);
    expect(tall['el-a']!.height, closeTo(0.3, 1e-9));
    expect(tall['el-a']!.width, closeTo(0.3, 1e-9));
  });
}
