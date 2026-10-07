import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// The pure snapping engine, exhaustively: every candidate type, the
/// tolerance boundary, the priority and tie-break rules, resize vs move
/// scope, and the disable flag. The slide is 1000x500 throughout.
const _slide = Size(1000, 500);

SnapEngine _engine({
  List<Rect> candidates = const [],
  List<ManualGuide> guides = const [],
  double? gridSpacing,
  double tolerance = 6,
}) => SnapEngine(
  slide: _slide,
  candidates: candidates,
  guides: guides,
  gridSpacing: gridSpacing,
  tolerance: tolerance,
);

void main() {
  group('element edges and centers', () {
    const candidate = Rect.fromLTWH(100, 100, 100, 100);

    test('a moving edge snaps to a candidate edge', () {
      final result = _engine(
        candidates: [candidate],
      ).snapMove(const Rect.fromLTWH(204, 300, 50, 40));
      expect(result.rect, const Rect.fromLTWH(200, 300, 50, 40));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.edge, orientation: SnapOrientation.vertical, position: 200),
      ]);
    });

    test('centers snap to centers on both axes at once', () {
      final result = _engine(
        candidates: [candidate],
      ).snapMove(const Rect.fromLTWH(127, 127, 50, 50));
      expect(result.rect, const Rect.fromLTWH(125, 125, 50, 50));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.center, orientation: SnapOrientation.vertical, position: 150),
        SnapLine(kind: SnapKind.center, orientation: SnapOrientation.horizontal, position: 150),
      ]);
    });

    test('an edge snap and a center snap combine across axes', () {
      final result = _engine(
        candidates: [candidate],
      ).snapMove(const Rect.fromLTWH(196, 122, 50, 52));
      expect(result.rect, const Rect.fromLTWH(200, 124, 50, 52));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.edge, orientation: SnapOrientation.vertical, position: 200),
        SnapLine(kind: SnapKind.center, orientation: SnapOrientation.horizontal, position: 150),
      ]);
    });

    test('a moving edge never snaps to a center line', () {
      // The candidate's vertical center line is 150; the moving left edge sits
      // 2px from it but the moving center (163) is far away: no snap.
      const moving = Rect.fromLTWH(148, 300, 30, 40);
      final result = _engine(candidates: [candidate]).snapMove(moving);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });

    test('the moving center never snaps to an edge line', () {
      // The candidate's right edge is 200; the moving center sits 2px from it
      // but both moving edges (177/227) are out of tolerance: no snap.
      const moving = Rect.fromLTWH(177, 300, 50, 40);
      final result = _engine(candidates: [candidate]).snapMove(moving);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });
  });

  group('slide edges and center', () {
    test('the slide edge snaps an empty engine', () {
      final result = _engine().snapMove(const Rect.fromLTWH(3, 300, 50, 40));
      expect(result.rect, const Rect.fromLTWH(0, 300, 50, 40));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.edge, orientation: SnapOrientation.vertical, position: 0),
      ]);
    });

    test('the slide center snaps the moving center', () {
      final result = _engine().snapMove(const Rect.fromLTWH(472, 300, 50, 40));
      expect(result.rect, const Rect.fromLTWH(475, 300, 50, 40));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.center, orientation: SnapOrientation.vertical, position: 500),
      ]);
    });

    test('far from everything nothing snaps', () {
      const moving = Rect.fromLTWH(311, 311, 50, 40);
      final result = _engine().snapMove(moving);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });
  });

  group('manual guides', () {
    test('a vertical guide snaps the nearest feature (an edge here)', () {
      final result = _engine(
        guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.3)],
      ).snapMove(const Rect.fromLTWH(297, 310, 50, 40));
      expect(result.rect, const Rect.fromLTWH(300, 310, 50, 40));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.guide, orientation: SnapOrientation.vertical, position: 300),
      ]);
    });

    test('a horizontal guide snaps the moving center too', () {
      final result = _engine(
        guides: const [ManualGuide(orientation: SnapOrientation.horizontal, position: 0.5)],
      ).snapMove(const Rect.fromLTWH(311, 232, 50, 40));
      expect(result.rect, const Rect.fromLTWH(311, 230, 50, 40));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.guide, orientation: SnapOrientation.horizontal, position: 250),
      ]);
    });

    test('a guide equidistant from edge and center snaps the edge', () {
      // Guide at 322.5: the moving left edge (320) and center (325) are both
      // 2.5 away; the earlier feature (the edge) wins the tie.
      final result = _engine(
        guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.3225)],
      ).snapMove(const Rect.fromLTWH(320, 310, 10, 40));
      expect(result.rect, const Rect.fromLTWH(322.5, 310, 10, 40));
    });
  });

  group('grid', () {
    test('a grid snaps moving edges to the nearest multiple', () {
      final result = _engine(gridSpacing: 50).snapMove(const Rect.fromLTWH(148, 337, 80, 76));
      expect(result.rect, const Rect.fromLTWH(150, 337, 80, 76));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.grid, orientation: SnapOrientation.vertical, position: 150),
      ]);
    });

    test('no grid config means no grid snapping', () {
      const moving = Rect.fromLTWH(148, 337, 80, 76);
      final result = _engine().snapMove(moving);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });
  });

  group('tolerance boundary', () {
    const candidate = [Rect.fromLTWH(100, 100, 100, 100)];

    test('a distance exactly at the tolerance snaps', () {
      final result = _engine(candidates: candidate).snapMove(const Rect.fromLTWH(206, 300, 50, 40));
      expect(result.rect.left, 200);
    });

    test('a distance just outside the tolerance does not', () {
      const moving = Rect.fromLTWH(206.5, 300, 50, 40);
      final result = _engine(candidates: candidate).snapMove(moving);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });
  });

  group('priority and tie-breaks', () {
    test('the nearest candidate wins regardless of kind', () {
      final engine = _engine(
        candidates: const [Rect.fromLTWH(200, 100, 100, 100)],
        guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.304)],
      );
      // Guide at 304, element edge at 300. From 303 the guide is nearer.
      expect(
        engine.snapMove(const Rect.fromLTWH(303, 310, 50, 40)).lines.single.kind,
        SnapKind.guide,
      );
      // From 301 the element edge is nearer, despite the guide's priority.
      expect(
        engine.snapMove(const Rect.fromLTWH(301, 310, 50, 40)).lines.single.kind,
        SnapKind.edge,
      );
    });

    test('an exact tie goes to the higher-priority kind (guide over element)', () {
      final result = _engine(
        candidates: const [Rect.fromLTWH(196, 100, 100, 100)],
        guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.304)],
      ).snapMove(const Rect.fromLTWH(300, 310, 50, 40));
      // The element edge (296) and the guide (304) are both 4 away.
      expect(result.rect.left, 304);
      expect(result.lines.single.kind, SnapKind.guide);
    });

    test('an exact tie between the slide and an element goes to the slide', () {
      final result = _engine(
        candidates: const [Rect.fromLTWH(892, 200, 100, 50)],
      ).snapMove(const Rect.fromLTWH(946, 310, 50, 40));
      // The moving right edge (996): slide edge 1000 and element edge 992 tie.
      expect(result.rect.left, 950);
      expect(result.lines.single.position, 1000);
    });

    test('an exact tie between two elements goes to the earlier one', () {
      final result = _engine(
        candidates: const [Rect.fromLTWH(196, 0, 100, 50), Rect.fromLTWH(304, 0, 100, 50)],
      ).snapMove(const Rect.fromLTWH(300, 310, 50, 40));
      // A's right edge (296) and B's left edge (304) are both 4 away: A wins.
      expect(result.rect.left, 296);
      expect(result.lines.single.position, 296);
    });
  });

  group('equal spacing', () {
    // A and B sit in a row (their vertical ranges overlap the moving rect's).
    const a = Rect.fromLTWH(100, 100, 100, 100);
    const b = Rect.fromLTWH(400, 110, 100, 80);

    test('the moving rect snaps to the position equalizing the gaps between two', () {
      final result = _engine(candidates: const [a, b]).snapMove(
        const Rect.fromLTWH(258, 120, 80, 40),
      );
      // Gap 200 between A and B; equal gaps put the moving center at 300.
      expect(result.rect, const Rect.fromLTWH(260, 120, 80, 40));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.spacing, orientation: SnapOrientation.vertical, position: 300),
      ]);
    });

    test('the sequence continues after the pair at the same gap', () {
      final result = _engine(candidates: const [a, b]).snapMove(
        const Rect.fromLTWH(704, 120, 80, 40),
      );
      // A|B gap is 200, so the next slot starts at B.right + 200 = 700.
      expect(result.rect.left, 700);
      expect(result.lines.single.kind, SnapKind.spacing);
    });

    test('the sequence continues before the pair at the same gap', () {
      final result = _engine(
        candidates: const [Rect.fromLTWH(400, 100, 100, 100), Rect.fromLTWH(700, 110, 100, 80)],
      ).snapMove(const Rect.fromLTWH(124, 120, 80, 40));
      // Gap 200; the slot before ends at A.left - 200 = 200.
      expect(result.rect, const Rect.fromLTWH(120, 120, 80, 40));
      expect(result.lines.single.kind, SnapKind.spacing);
    });

    test('no spacing hints without a cross-axis alignment', () {
      // The same geometry as the between case, but the moving rect sits far
      // below the pair: no row, no hint.
      const moving = Rect.fromLTWH(258, 420, 80, 40);
      final result = _engine(candidates: const [a, b]).snapMove(moving);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });

    test('no between hint when the moving rect is wider than the gap', () {
      const moving = Rect.fromLTWH(188, 120, 220, 40);
      final result = _engine(candidates: const [a, b]).snapMove(moving);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });

    test('overlapping candidates establish no gap and no hints', () {
      const moving = Rect.fromLTWH(311, 120, 50, 40);
      final result = _engine(
        candidates: const [Rect.fromLTWH(100, 100, 200, 100), Rect.fromLTWH(250, 110, 150, 80)],
      ).snapMove(moving);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });
  });

  group('resize', () {
    const candidate = Rect.fromLTWH(200, 300, 100, 50);

    test('the dragged right edge snaps; the left edge stays pinned', () {
      final result = _engine(candidates: const [candidate]).snapResize(
        const Rect.fromLTWH(100, 100, 104, 50),
        movingX: 1,
        movingY: 0,
      );
      expect(result.rect, const Rect.fromLTWH(100, 100, 100, 50));
      expect(result.lines, const [
        SnapLine(kind: SnapKind.edge, orientation: SnapOrientation.vertical, position: 200),
      ]);
    });

    test('the dragged left edge snaps; the right edge stays pinned', () {
      final result = _engine(candidates: const [candidate]).snapResize(
        const Rect.fromLTWH(204, 100, 96, 50),
        movingX: -1,
        movingY: 0,
      );
      expect(result.rect, const Rect.fromLTRB(200, 100, 300, 150));
    });

    test('the non-dragged edge never snaps', () {
      // The left edge (98) is 2px from the candidate line at 100 wide, but
      // only the dragged right edge participates.
      const moving = Rect.fromLTWH(98, 100, 304, 50);
      final result = _engine(
        candidates: const [Rect.fromLTWH(100, 300, 20, 50)],
      ).snapResize(moving, movingX: 1, movingY: 0);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });

    test('a corner drag snaps both dragged edges', () {
      final result = _engine(candidates: const [candidate]).snapResize(
        const Rect.fromLTWH(100, 100, 104, 196),
        movingX: 1,
        movingY: 1,
      );
      expect(result.rect, const Rect.fromLTRB(100, 100, 200, 300));
      expect(result.lines, hasLength(2));
    });

    test('the resized rect center never snaps', () {
      // The rect's center x (150) matches the candidate's center exactly, but
      // resize considers the dragged edge alone.
      const moving = Rect.fromLTWH(120, 100, 60, 50);
      final result = _engine(
        candidates: const [Rect.fromLTWH(100, 300, 100, 50)],
      ).snapResize(moving, movingX: 1, movingY: 0);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });

    test('spacing hints are not offered on resize', () {
      const moving = Rect.fromLTWH(100, 120, 604, 40);
      final result = _engine(
        candidates: const [Rect.fromLTWH(100, 100, 100, 100), Rect.fromLTWH(400, 110, 100, 80)],
      ).snapResize(moving, movingX: 1, movingY: 0);
      // 704 is the spacing continuation slot; the edge must not take it.
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });

    test('a dragged edge snaps to a guide', () {
      final result = _engine(
        guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.3)],
      ).snapResize(const Rect.fromLTWH(100, 100, 197, 50), movingX: 1, movingY: 0);
      expect(result.rect, const Rect.fromLTRB(100, 100, 300, 150));
      expect(result.lines.single.kind, SnapKind.guide);
    });

    test('a dragged edge snaps to the grid', () {
      final result = _engine(gridSpacing: 50).snapResize(
        const Rect.fromLTWH(100, 100, 198, 50),
        movingX: 1,
        movingY: 0,
      );
      expect(result.rect, const Rect.fromLTRB(100, 100, 300, 150));
      expect(result.lines.single.kind, SnapKind.grid);
    });

    test('a vertical-only handle leaves x alone', () {
      final result = _engine(candidates: const [candidate]).snapResize(
        const Rect.fromLTWH(196, 100, 50, 204),
        movingX: 0,
        movingY: 1,
      );
      // The left edge (196) is within tolerance of 200 but x is not dragged;
      // the bottom edge (304) snaps to the candidate's top (300).
      expect(result.rect, const Rect.fromLTWH(196, 100, 50, 200));
      expect(result.lines.single.orientation, SnapOrientation.horizontal);
    });
  });

  group('the disable flag', () {
    const candidate = [Rect.fromLTWH(100, 100, 100, 100)];

    test('a disabled move snap returns the rect untouched', () {
      const moving = Rect.fromLTWH(204, 300, 50, 40);
      final result = _engine(candidates: candidate).snapMove(moving, disabled: true);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });

    test('a disabled resize snap returns the rect untouched', () {
      const moving = Rect.fromLTWH(100, 100, 104, 50);
      final result = _engine(
        candidates: const [Rect.fromLTWH(200, 300, 100, 50)],
      ).snapResize(moving, movingX: 1, movingY: 0, disabled: true);
      expect(result.rect, moving);
      expect(result.lines, isEmpty);
    });
  });

  group('SnapLine', () {
    test('equality and hashing follow the value', () {
      const line = SnapLine(
        kind: SnapKind.edge,
        orientation: SnapOrientation.vertical,
        position: 200,
      );
      const same = SnapLine(
        kind: SnapKind.edge,
        orientation: SnapOrientation.vertical,
        position: 200,
      );
      const other = SnapLine(
        kind: SnapKind.center,
        orientation: SnapOrientation.vertical,
        position: 200,
      );
      expect(line, same);
      expect(line.hashCode, same.hashCode);
      expect(line, isNot(other));
      expect('$line', contains('200'));
    });
  });
}
