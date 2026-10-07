import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {'id': 'el-1', 'type': 'Box', 'color': '#111111'},
        {'id': 'el-2', 'type': 'Box', 'color': '#222222'},
        {'id': 'el-3', 'type': 'Box', 'color': '#333333'},
        {'id': 'el-4', 'type': 'Box', 'color': '#444444'},
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {'id': 'el-ga', 'type': 'Box', 'color': '#AAAAAA'},
            {'id': 'el-gb', 'type': 'Box', 'color': '#BBBBBB'},
            {'id': 'el-gc', 'type': 'Box', 'color': '#CCCCCC'},
          ],
        },
      ],
    },
  ],
};

void main() {
  group('arrangedIds (the pure algorithm)', () {
    const order = ['a', 'b', 'c', 'd'];

    test('forward swaps each moved id with the unselected neighbor above', () {
      expect(arrangedIds(order, {'b'}, ArrangeOrder.forward), ['a', 'c', 'b', 'd']);
    });

    test('forward at the top is a no-op', () {
      expect(arrangedIds(order, {'d'}, ArrangeOrder.forward), order);
    });

    test('forward keeps a moved run intact (Figma semantics)', () {
      expect(arrangedIds(order, {'b', 'c'}, ArrangeOrder.forward), ['a', 'd', 'b', 'c']);
      expect(arrangedIds(order, {'c', 'd'}, ArrangeOrder.forward), order);
    });

    test('backward mirrors forward', () {
      expect(arrangedIds(order, {'c'}, ArrangeOrder.backward), ['a', 'c', 'b', 'd']);
      expect(arrangedIds(order, {'a'}, ArrangeOrder.backward), order);
      expect(arrangedIds(order, {'b', 'c'}, ArrangeOrder.backward), ['b', 'c', 'a', 'd']);
    });

    test('front lifts the moved set to the top, order preserved', () {
      expect(arrangedIds(order, {'a', 'c'}, ArrangeOrder.front), ['b', 'd', 'a', 'c']);
    });

    test('back drops the moved set to the bottom, order preserved', () {
      expect(arrangedIds(order, {'b', 'd'}, ArrangeOrder.back), ['b', 'd', 'a', 'c']);
    });

    test('ids outside the order are ignored', () {
      expect(arrangedIds(order, {'zz', 'b'}, ArrangeOrder.forward), ['a', 'c', 'b', 'd']);
      expect(arrangedIds(order, {'zz'}, ArrangeOrder.front), order);
    });
  });

  group('EditorDocument.arrangeOrder', () {
    test('reorders top-level elements', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.arrangeOrder(['el-1', 'el-3'], ArrangeOrder.front);
      expect(next.elementIdsInScene(0), ['el-2', 'el-4', 'el-g', 'el-1', 'el-3']);
    });

    test('reorders within a group children list', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.arrangeOrder(['el-ga'], ArrangeOrder.forward);
      expect(next.childIdsOfGroup('el-g'), ['el-gb', 'el-ga', 'el-gc']);
      expect(next.elementIdsInScene(0), doc.elementIdsInScene(0));
    });

    test('a mixed selection arranges each holding list independently', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.arrangeOrder(['el-1', 'el-ga'], ArrangeOrder.front);
      expect(next.elementIdsInScene(0), ['el-2', 'el-3', 'el-4', 'el-g', 'el-1']);
      expect(next.childIdsOfGroup('el-g'), ['el-gb', 'el-gc', 'el-ga']);
    });

    test('unknown ids throw', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(() => doc.arrangeOrder(['missing'], ArrangeOrder.front), throwsArgumentError);
    });
  });

  group('ArrangeOrderCommand', () {
    test('applies through history and undoes exactly', () {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc);
      const command = ArrangeOrderCommand(ids: ['el-2'], order: ArrangeOrder.back);
      expect(command.label, 'Send to back');
      expect(command.affectedIds, {'el-2'});
      history.dispatch(command);
      expect(history.document.elementIdsInScene(0), ['el-2', 'el-1', 'el-3', 'el-4', 'el-g']);
      history.undo();
      expect(history.document.toJson(), doc.toJson());
    });

    test('each order op carries its own label', () {
      expect(
        const ArrangeOrderCommand(ids: ['x'], order: ArrangeOrder.forward).label,
        'Bring forward',
      );
      expect(
        const ArrangeOrderCommand(ids: ['x'], order: ArrangeOrder.backward).label,
        'Send backward',
      );
      expect(
        const ArrangeOrderCommand(ids: ['x'], order: ArrangeOrder.front).label,
        'Bring to front',
      );
    });
  });
}
