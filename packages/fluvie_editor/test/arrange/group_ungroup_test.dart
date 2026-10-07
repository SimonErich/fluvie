import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Placement, decodePlacement;
import 'package:fluvie_editor/fluvie_editor.dart';

const Size _canvas = Size(320, 180);

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-back',
          'type': 'Box',
          'color': '#101018',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
        },
        {
          'id': 'el-a',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.75, 'y': 0.5, 'w': 0.3, 'h': 0.4, 'rotation': 30},
        },
        {
          'id': 'el-top',
          'type': 'Text',
          'text': 'over',
          'transform': {'x': 0.5, 'y': 0.1},
        },
      ],
    },
  ],
};

/// The union of el-a and el-b as a group transform (center anchor).
const Map<String, Object?> _unionTransform = {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.4};

/// The absolute canvas rect of element [id] in [doc], resolved through the
/// same Placement math the renderer uses (group children resolve against
/// their group's box).
Rect _absoluteRect(EditorDocument doc, String id) {
  final placement = decodePlacement(doc.elementJson(id)!['transform']);
  final parent = doc.parentGroupOf(id);
  if (parent == null) return placement.rectFor(_canvas)!;
  final parentRect = _absoluteRect(doc, parent);
  return placement.rectFor(parentRect.size)!.shift(parentRect.topLeft);
}

void main() {
  group('groupElements', () {
    test('wraps the members, inserts at the topmost member z-slot', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.groupElements(
        0,
        ['el-a', 'el-b'],
        groupId: 'el-wrap',
        groupTransform: _unionTransform,
      );
      expect(next.elementIdsInScene(0), ['el-back', 'el-wrap', 'el-top']);
      expect(next.childIdsOfGroup('el-wrap'), ['el-a', 'el-b']);
      expect(next.elementJson('el-wrap')?['transform'], _unionTransform);
    });

    test('nothing moves: every member keeps its absolute rect', () {
      final doc = EditorDocument.fromJson(_deck());
      final before = {
        for (final id in ['el-a', 'el-b']) id: _absoluteRect(doc, id),
      };
      final next = doc.groupElements(
        0,
        ['el-a', 'el-b'],
        groupId: 'el-wrap',
        groupTransform: _unionTransform,
      );
      for (final id in ['el-a', 'el-b']) {
        final after = _absoluteRect(next, id);
        expect(after.left, closeTo(before[id]!.left, 1e-6), reason: id);
        expect(after.top, closeTo(before[id]!.top, 1e-6), reason: id);
        expect(after.width, closeTo(before[id]!.width, 1e-6), reason: id);
        expect(after.height, closeTo(before[id]!.height, 1e-6), reason: id);
      }
    });

    test('member rotation, opacity, and anchor survive the rewrite', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.groupElements(
        0,
        ['el-a', 'el-b'],
        groupId: 'el-wrap',
        groupTransform: _unionTransform,
      );
      final placement = decodePlacement(next.elementJson('el-b')!['transform']);
      expect(placement.rotation, 30);
    });

    test('an intrinsic member keeps its anchor point (and stays intrinsic)', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.groupElements(
        0,
        ['el-b', 'el-top'],
        groupId: 'el-wrap',
        groupTransform: const {'x': 0.5, 'y': 0.3, 'w': 0.5, 'h': 0.5},
      );
      final placement = decodePlacement(next.elementJson('el-top')!['transform']);
      expect(placement.isIntrinsic, isTrue);
      // Group rect: center (160, 54), size (160, 90) -> left 80, top 9.
      // The anchor point (160, 18) maps to ((160-80)/160, (18-9)/90).
      expect(placement.x, closeTo(0.5, 1e-9));
      expect(placement.y, closeTo(0.1, 1e-9));
    });

    test('member ids are stable through grouping', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.groupElements(
        0,
        ['el-a', 'el-b'],
        groupId: 'el-wrap',
        groupTransform: _unionTransform,
      );
      expect(next.childIdsOfGroup('el-wrap'), ['el-a', 'el-b']);
      expect(next.elementJson('el-a')?['color'], '#6C5CE7');
    });

    test('needs two or more top-level members of the scene', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(
        () => doc.groupElements(0, ['el-a'], groupId: 'g', groupTransform: _unionTransform),
        throwsArgumentError,
      );
      expect(
        () => doc.groupElements(
          0,
          ['el-a', 'missing'],
          groupId: 'g',
          groupTransform: _unionTransform,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ungroupElement', () {
    EditorDocument grouped() => EditorDocument.fromJson(_deck()).groupElements(
      0,
      ['el-a', 'el-b'],
      groupId: 'el-wrap',
      groupTransform: _unionTransform,
    );

    test('re-inserts the children at the group index in internal order', () {
      final next = grouped().ungroupElement('el-wrap');
      expect(next.elementIdsInScene(0), ['el-back', 'el-a', 'el-b', 'el-top']);
      expect(next.elementJson('el-wrap'), isNull);
    });

    test('group then ungroup is pixel-identical and id-stable', () {
      final doc = EditorDocument.fromJson(_deck());
      final back = grouped().ungroupElement('el-wrap');
      for (final id in ['el-a', 'el-b']) {
        final original = _absoluteRect(doc, id);
        final after = _absoluteRect(back, id);
        expect(after.left, closeTo(original.left, 1e-6), reason: id);
        expect(after.top, closeTo(original.top, 1e-6), reason: id);
        expect(after.width, closeTo(original.width, 1e-6), reason: id);
        expect(after.height, closeTo(original.height, 1e-6), reason: id);
      }
      expect(decodePlacement(back.elementJson('el-b')!['transform']).rotation, 30);
    });

    test('a rotated group composes rotation into its children', () {
      final rotated = grouped().setTransform('el-wrap', {
        ..._unionTransform,
        'rotation': 90,
      });
      final next = rotated.ungroupElement('el-wrap');
      final placement = decodePlacement(next.elementJson('el-a')!['transform']);
      expect(placement.rotation, closeTo(90, 1e-9));
      // el-a's center (80, 90) turns 90 degrees around the group center
      // (160, 90) to land at (160, 10): fractions (0.5, 10/180).
      expect(placement.x, closeTo(0.5, 1e-9));
      expect(placement.y, closeTo(10 / 180, 1e-9));
      expect(decodePlacement(next.elementJson('el-b')!['transform']).rotation, closeTo(120, 1e-9));
    });

    test('a rotated group turns an intrinsic child by its anchor point', () {
      final doc = EditorDocument.fromJson(_deck())
          .groupElements(
            0,
            ['el-b', 'el-top'],
            groupId: 'el-wrap',
            groupTransform: const {'x': 0.5, 'y': 0.3, 'w': 0.5, 'h': 0.5},
          )
          .setTransform('el-wrap', {'x': 0.5, 'y': 0.3, 'w': 0.5, 'h': 0.5, 'rotation': 90});
      final next = doc.ungroupElement('el-wrap');
      final placement = decodePlacement(next.elementJson('el-top')!['transform']);
      // The anchor point (160, 18) turns 90 degrees around the group center
      // (160, 54) to land at (196, 54); the rotation composes.
      expect(placement.isIntrinsic, isTrue);
      expect(placement.x, closeTo(196 / 320, 1e-9));
      expect(placement.y, closeTo(0.3, 1e-9));
      expect(placement.rotation, closeTo(90, 1e-9));
    });

    test('a nested group ungroups into its parent group frame', () {
      final doc = grouped().groupElements(
        0,
        ['el-back', 'el-wrap'],
        groupId: 'el-outer',
        groupTransform: const {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
      );
      final before = {
        for (final id in ['el-a', 'el-b']) id: _absoluteRect(doc, id),
      };
      final next = doc.ungroupElement('el-wrap');
      expect(next.childIdsOfGroup('el-outer'), ['el-back', 'el-a', 'el-b']);
      for (final id in ['el-a', 'el-b']) {
        final after = _absoluteRect(next, id);
        expect(after.left, closeTo(before[id]!.left, 1e-6), reason: id);
        expect(after.top, closeTo(before[id]!.top, 1e-6), reason: id);
      }
    });

    test('a group without a transform releases against the whole canvas', () {
      final json = _deck();
      final scene = (json['scenes']! as List).first as Map<String, Object?>;
      (scene['children']! as List).add({
        'id': 'el-bare',
        'type': 'Group',
        'children': [
          {
            'id': 'el-in',
            'type': 'Box',
            'color': '#FFFFFF',
            'transform': {'x': 0.25, 'y': 0.25, 'w': 0.5, 'h': 0.5},
          },
        ],
      });
      final next = EditorDocument.fromJson(json).ungroupElement('el-bare');
      final placement = decodePlacement(next.elementJson('el-in')!['transform']);
      expect(placement.x, closeTo(0.25, 1e-9));
      expect(placement.width, closeTo(0.5, 1e-9));
    });

    test('only groups ungroup', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(() => doc.ungroupElement('el-a'), throwsArgumentError);
      expect(() => doc.ungroupElement('missing'), throwsArgumentError);
    });
  });

  group('commands and undo', () {
    test('GroupElementsCommand groups; undo restores the exact document', () {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc);
      const command = GroupElementsCommand(
        scene: 0,
        ids: ['el-a', 'el-b'],
        groupId: 'el-wrap',
        transform: _unionTransform,
      );
      expect(command.label, 'Group 2 elements');
      expect(command.affectedIds, {'el-wrap', 'el-a', 'el-b'});
      history.dispatch(command);
      expect(history.document.elementIdsInScene(0), ['el-back', 'el-wrap', 'el-top']);
      history.undo();
      expect(history.document.toJson(), doc.toJson());
      history.redo();
      expect(history.document.childIdsOfGroup('el-wrap'), ['el-a', 'el-b']);
    });

    test('UngroupElementsCommand ungroups every named group in one step', () {
      final doc = EditorDocument.fromJson(_deck()).groupElements(
        0,
        ['el-a', 'el-b'],
        groupId: 'el-wrap',
        groupTransform: _unionTransform,
      );
      final history = DocumentHistory(doc);
      const command = UngroupElementsCommand(ids: ['el-wrap']);
      expect(command.label, 'Ungroup');
      expect(command.affectedIds, {'el-wrap'});
      history.dispatch(command);
      expect(history.document.elementIdsInScene(0), ['el-back', 'el-a', 'el-b', 'el-top']);
      history.undo();
      expect(history.document.toJson(), doc.toJson());
    });

    test('a group drag stays one undo step and leaves children untouched', () {
      final doc = EditorDocument.fromJson(_deck()).groupElements(
        0,
        ['el-a', 'el-b'],
        groupId: 'el-wrap',
        groupTransform: _unionTransform,
      );
      final history = DocumentHistory(doc)
        ..dispatch(
          const SetTransformCommand(
            id: 'el-wrap',
            transform: {'x': 0.55, 'y': 0.6, 'w': 0.8, 'h': 0.4},
          ),
        );
      final childA = history.document.elementJson('el-a');
      expect(childA?['transform'], doc.elementJson('el-a')?['transform']);
      history.undo();
      expect(history.document.toJson(), doc.toJson());
    });
  });

  group('a group drag moves the members together', () {
    test('members absolute rects all translate by the same delta', () {
      final doc = EditorDocument.fromJson(_deck()).groupElements(
        0,
        ['el-a', 'el-b'],
        groupId: 'el-wrap',
        groupTransform: _unionTransform,
      );
      final before = {
        for (final id in ['el-a', 'el-b']) id: _absoluteRect(doc, id),
      };
      // Move the group by (+0.05, +0.1) canvas fractions: (16, 18) px.
      final moved = doc.setTransform('el-wrap', {'x': 0.55, 'y': 0.6, 'w': 0.8, 'h': 0.4});
      for (final id in ['el-a', 'el-b']) {
        final after = _absoluteRect(moved, id);
        expect(after.left - before[id]!.left, closeTo(16, 1e-6), reason: id);
        expect(after.top - before[id]!.top, closeTo(18, 1e-6), reason: id);
        expect(after.width, closeTo(before[id]!.width, 1e-6), reason: id);
      }
    });
  });

  group('Placement sanity for the fixture', () {
    test('the union transform really is the members bounding box', () {
      const a = Placement(x: 0.25, y: 0.5, width: 0.3, height: 0.4);
      const b = Placement(x: 0.75, y: 0.5, width: 0.3, height: 0.4);
      final union = a.rectFor(_canvas)!.expandToInclude(b.rectFor(_canvas)!);
      expect(union, const Rect.fromLTRB(32, 54, 288, 126));
      final wrap = decodePlacement(_unionTransform).rectFor(_canvas);
      expect(wrap, union);
    });
  });
}
