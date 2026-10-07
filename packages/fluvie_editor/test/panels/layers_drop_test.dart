import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

LayerRowEntry _row(String id, {String? parent, bool isGroup = false, bool expanded = false}) => (
  id: id,
  parent: parent,
  isGroup: isGroup,
  expanded: expanded,
);

/// The fixture panel, topmost first: two loose rows, an expanded group with
/// two children, one more loose row.
///
/// ```text
/// 0 top      (z 3 of 4)
/// 1 mid      (z 2)
/// 2 g        (z 1, expanded)
/// 3   ga     (child z 1 of 2)
/// 4   gb     (child z 0)
/// 5 bottom   (z 0)
/// ```
List<LayerRowEntry> _rows() => [
  _row('top'),
  _row('mid'),
  _row('g', isGroup: true, expanded: true),
  _row('ga', parent: 'g'),
  _row('gb', parent: 'g'),
  _row('bottom'),
];

void main() {
  group('plain reorders', () {
    test('a top-level drop between top-level rows reorders', () {
      // "top" dropped below "mid" (insert slot 2 pre-removal).
      final plan = layersDropPlan(_rows(), 0, 2)! as LayersReorder;
      expect(plan.id, 'top');
      expect(plan.to, 2);
    });

    test('a child drop within its own group reorders the child list', () {
      // "ga" dropped below "gb" (post-removal panel slot after gb).
      final plan = layersDropPlan(_rows(), 3, 5)! as LayersReorder;
      expect(plan.id, 'ga');
      expect(plan.to, 0);
    });

    test('a drop in place is a no-op', () {
      expect(layersDropPlan(_rows(), 1, 1), isNull);
      expect(layersDropPlan(_rows(), 1, 2), isNull);
      expect(layersDropPlan(_rows(), 4, 5), isNull);
    });
  });

  group('moves into a group', () {
    test('a drop right under the expanded group row enters topmost', () {
      final plan = layersDropPlan(_rows(), 1, 3)! as LayersMoveIn;
      expect(plan.id, 'mid');
      expect(plan.group, 'g');
      expect(plan.at, 2);
    });

    test('a drop between the children enters at the slot', () {
      final plan = layersDropPlan(_rows(), 1, 4)! as LayersMoveIn;
      expect(plan.id, 'mid');
      expect(plan.at, 1);
    });

    test('a drop after the last child enters at the bottom', () {
      final plan = layersDropPlan(_rows(), 1, 5)! as LayersMoveIn;
      expect(plan.id, 'mid');
      expect(plan.at, 0);
    });

    test('a collapsed group opens no slots', () {
      final rows = [
        _row('top'),
        _row('g', isGroup: true),
        _row('bottom'),
      ];
      final plan = layersDropPlan(rows, 0, 2)! as LayersReorder;
      expect(plan.id, 'top');
      expect(plan.to, 1);
    });

    test('a group row never nests: the drop lands beside instead', () {
      final rows = [
        _row('h', isGroup: true),
        _row('g', isGroup: true, expanded: true),
        _row('ga', parent: 'g'),
        _row('bottom'),
      ];
      // "h" dropped between g's children clamps to the top level under g.
      final plan = layersDropPlan(rows, 0, 3)! as LayersReorder;
      expect(plan.id, 'h');
      expect(plan.to, 1);
    });

    test('a child moves between groups', () {
      final rows = [
        _row('g', isGroup: true, expanded: true),
        _row('ga', parent: 'g'),
        _row('h', isGroup: true, expanded: true),
        _row('ha', parent: 'h'),
      ];
      final plan = layersDropPlan(rows, 1, 4)! as LayersMoveIn;
      expect(plan.id, 'ga');
      expect(plan.group, 'h');
      // Dropped below "ha": the bottom child slot.
      expect(plan.at, 0);
    });

    test("a drop among the dragged group's own children is a no-op", () {
      final plan = layersDropPlan(_rows(), 2, 4);
      expect(plan, isNull);
    });
  });

  group('moves out of a group', () {
    test('a child dropped above the group promotes at the slot', () {
      final plan = layersDropPlan(_rows(), 3, 1)! as LayersMoveOut;
      expect(plan.id, 'ga');
      expect(plan.group, 'g');
      // Above "mid": one top-level row above the slot, four already there.
      expect(plan.at, 3);
    });

    test('a child dropped at the very top promotes topmost', () {
      final plan = layersDropPlan(_rows(), 4, 0)! as LayersMoveOut;
      expect(plan.id, 'gb');
      expect(plan.at, 4);
    });

    test('a child dropped below the whole panel promotes to the bottom', () {
      final plan = layersDropPlan(_rows(), 3, 6)! as LayersMoveOut;
      expect(plan.id, 'ga');
      expect(plan.at, 0);
    });
  });
}
