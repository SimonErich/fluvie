import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:flutter/widgets.dart' show Offset, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  const rect = Rect.fromLTWH(100, 50, 200, 100);

  group('handlePoint', () {
    test('unrotated handles sit on the rect corners and edge midpoints', () {
      const gizmo = GizmoGeometry(rect: rect);
      expect(gizmo.handlePoint(GizmoHandle.topLeft), const Offset(100, 50));
      expect(gizmo.handlePoint(GizmoHandle.top), const Offset(200, 50));
      expect(gizmo.handlePoint(GizmoHandle.topRight), const Offset(300, 50));
      expect(gizmo.handlePoint(GizmoHandle.right), const Offset(300, 100));
      expect(gizmo.handlePoint(GizmoHandle.bottomRight), const Offset(300, 150));
      expect(gizmo.handlePoint(GizmoHandle.bottom), const Offset(200, 150));
      expect(gizmo.handlePoint(GizmoHandle.bottomLeft), const Offset(100, 150));
      expect(gizmo.handlePoint(GizmoHandle.left), const Offset(100, 100));
    });

    test('rotation turns the handles with the element', () {
      const gizmo = GizmoGeometry(rect: rect, rotation: 90);
      final topLeft = gizmo.handlePoint(GizmoHandle.topLeft);
      expect(topLeft.dx, closeTo(250, 1e-9));
      expect(topLeft.dy, closeTo(0, 1e-9));
      final right = gizmo.handlePoint(GizmoHandle.right);
      expect(right.dx, closeTo(200, 1e-9));
      expect(right.dy, closeTo(200, 1e-9));
    });
  });

  group('hitTest', () {
    const gizmo = GizmoGeometry(rect: rect);

    test('a point on a handle resizes, and handles win over the body', () {
      expect(gizmo.hitTest(const Offset(101, 51)), const GizmoResize(GizmoHandle.topLeft));
      expect(gizmo.hitTest(const Offset(300, 100)), const GizmoResize(GizmoHandle.right));
      expect(gizmo.hitTest(const Offset(200, 148)), const GizmoResize(GizmoHandle.bottom));
    });

    test('just outside a corner rotates', () {
      expect(gizmo.hitTest(const Offset(110, 40)), const GizmoRotate(GizmoHandle.topLeft));
      expect(gizmo.hitTest(const Offset(310, 160)), const GizmoRotate(GizmoHandle.bottomRight));
    });

    test('inside the shape is the body; the corner zone never fires inside', () {
      expect(gizmo.hitTest(const Offset(200, 100)), const GizmoBody());
      expect(gizmo.hitTest(const Offset(110, 60)), const GizmoBody());
    });

    test('far away hits nothing', () {
      expect(gizmo.hitTest(const Offset(500, 400)), isNull);
      expect(gizmo.hitTest(const Offset(130, 20)), isNull);
    });

    test('hit zones rotate with the element', () {
      const rotated = GizmoGeometry(rect: rect, rotation: 90);
      // The rotated topLeft handle sits at (250, 0).
      expect(rotated.hitTest(const Offset(251, 1)), const GizmoResize(GizmoHandle.topLeft));
      // The rect center never moves.
      expect(rotated.hitTest(const Offset(200, 100)), const GizmoBody());
      // The old corner position is empty space now.
      expect(rotated.hitTest(const Offset(100, 50)), isNull);
    });

    test('the radii are caller-tunable', () {
      expect(gizmo.hitTest(const Offset(112, 50), handleRadius: 15), isNot(isNull));
      expect(
        gizmo.hitTest(const Offset(125, 25), rotationRadius: 40),
        const GizmoRotate(GizmoHandle.topLeft),
      );
    });
  });

  group('cursorFor', () {
    test('resize cursors follow the handle direction', () {
      const gizmo = GizmoGeometry(rect: rect);
      expect(
        gizmo.cursorFor(const GizmoResize(GizmoHandle.right)),
        SystemMouseCursors.resizeLeftRight,
      );
      expect(gizmo.cursorFor(const GizmoResize(GizmoHandle.top)), SystemMouseCursors.resizeUpDown);
      expect(
        gizmo.cursorFor(const GizmoResize(GizmoHandle.bottomRight)),
        SystemMouseCursors.resizeUpLeftDownRight,
      );
      expect(
        gizmo.cursorFor(const GizmoResize(GizmoHandle.topRight)),
        SystemMouseCursors.resizeUpRightDownLeft,
      );
    });

    test('resize cursors follow the element rotation', () {
      const quarter = GizmoGeometry(rect: rect, rotation: 90);
      expect(
        quarter.cursorFor(const GizmoResize(GizmoHandle.right)),
        SystemMouseCursors.resizeUpDown,
      );
      const eighth = GizmoGeometry(rect: rect, rotation: 45);
      expect(
        eighth.cursorFor(const GizmoResize(GizmoHandle.right)),
        SystemMouseCursors.resizeUpLeftDownRight,
      );
    });

    test('the body moves and the rotation zones grab', () {
      const gizmo = GizmoGeometry(rect: rect);
      expect(gizmo.cursorFor(const GizmoBody()), SystemMouseCursors.move);
      expect(gizmo.cursorFor(const GizmoRotate(GizmoHandle.topLeft)), SystemMouseCursors.grab);
    });
  });
  equalitySuite();
}

// Hit values travel through session state and rebuild checks, so their
// equality is behavior, not boilerplate. Runtime construction on one side
// keeps const canonicalization from short-circuiting the operators.
void equalitySuite() {
  test('hits and geometry compare by value', () {
    // ignore: prefer_const_constructors, a const pair would be identical and never run ==.
    expect(GizmoBody(), const GizmoBody());
    // ignore: prefer_const_constructors, same.
    expect(GizmoBody().hashCode, const GizmoBody().hashCode);
    // ignore: prefer_const_constructors, same.
    expect(GizmoResize(GizmoHandle.top), const GizmoResize(GizmoHandle.top));
    // ignore: prefer_const_constructors, same.
    expect(GizmoResize(GizmoHandle.top), isNot(const GizmoResize(GizmoHandle.left)));
    // ignore: prefer_const_constructors, same.
    expect(GizmoResize(GizmoHandle.top).hashCode, const GizmoResize(GizmoHandle.top).hashCode);
    // ignore: prefer_const_constructors, same.
    expect(GizmoRotate(GizmoHandle.topLeft), const GizmoRotate(GizmoHandle.topLeft));
    expect(
      const GizmoRotate(GizmoHandle.topLeft).hashCode,
      const GizmoRotate(GizmoHandle.topLeft).hashCode,
    );
    // ignore: prefer_const_constructors, same.
    expect(GizmoRotate(GizmoHandle.topLeft), isNot(const GizmoBody()));
    // ignore: prefer_const_constructors, same.
    final gizmo = GizmoGeometry(rect: const Rect.fromLTWH(0, 0, 10, 10), rotation: 5);
    expect(gizmo, const GizmoGeometry(rect: Rect.fromLTWH(0, 0, 10, 10), rotation: 5));
    expect(
      gizmo.hashCode,
      const GizmoGeometry(rect: Rect.fromLTWH(0, 0, 10, 10), rotation: 5).hashCode,
    );
    expect(gizmo, isNot(const GizmoGeometry(rect: Rect.fromLTWH(0, 0, 10, 10))));
  });
}
