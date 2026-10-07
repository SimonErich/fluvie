import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({double groupRotation = 0}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-loose',
          'type': 'Box',
          'color': '#E17055',
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {
            'x': 0.65,
            'y': 0.5,
            'w': 0.5,
            'h': 0.6,
            if (groupRotation != 0) 'rotation': groupRotation,
          },
          'children': [
            {
              'id': 'el-ga',
              'type': 'Box',
              'color': '#AAAAAA',
              'transform': {'x': 0.3, 'y': 0.5, 'w': 0.4, 'h': 0.4},
            },
            {
              'id': 'el-gb',
              'type': 'Box',
              'color': '#BBBBBB',
              'transform': {'x': 0.7, 'y': 0.5, 'w': 0.4, 'h': 0.4},
            },
          ],
        },
      ],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

/// The absolute canvas rect of [id], resolved through the same geometry the
/// canvas hits (children map through their group frame).
Rect _absRect(EditorDocument document, String id) {
  final top = SceneGeometry.of(document, 0).rectOf(id);
  if (top != null) return top;
  return SceneGeometry.of(document, 0, enteredGroup: document.parentGroupOf(id)).rectOf(id)!;
}

void main() {
  group('moveIntoGroup', () {
    test('rewrites the transform group-relative so nothing moves', () {
      final document = EditorDocument.fromJson(_deck());
      final before = _absRect(document, 'el-loose');
      final moved = document.moveIntoGroup('el-loose', groupId: 'el-g', at: 2);
      expect(moved.parentGroupOf('el-loose'), 'el-g');
      expect(moved.childIdsOfGroup('el-g'), ['el-ga', 'el-gb', 'el-loose']);
      expect(moved.elementIdsInScene(0), ['el-g']);
      final after = _absRect(moved, 'el-loose');
      expect(after.left, closeTo(before.left, 1e-6));
      expect(after.top, closeTo(before.top, 1e-6));
      expect(after.width, closeTo(before.width, 1e-6));
      expect(after.height, closeTo(before.height, 1e-6));
    });

    test('the child z-position follows the drop slot', () {
      final document = EditorDocument.fromJson(_deck());
      final moved = document.moveIntoGroup('el-loose', groupId: 'el-g', at: 0);
      expect(moved.childIdsOfGroup('el-g'), ['el-loose', 'el-ga', 'el-gb']);
    });

    test('a rotated group composes the rotation out and round-trips exactly', () {
      final document = EditorDocument.fromJson(_deck(groupRotation: 30));
      final before = document.elementJson('el-loose')!['transform']! as Map<String, Object?>;
      final moved = document.moveIntoGroup('el-loose', groupId: 'el-g', at: 2);
      final inside = moved.elementJson('el-loose')!['transform']! as Map<String, Object?>;
      // The member's own rotation shrinks by the group's, so the rendered
      // shape (rotation composed back in by Placed) keeps its orientation.
      expect((inside['rotation']! as num).toDouble(), closeTo(-30, 1e-9));
      final back = moved.moveOutOfGroup('el-loose', at: 1);
      final restored = back.elementJson('el-loose')!['transform']! as Map<String, Object?>;
      for (final key in ['x', 'y', 'w', 'h']) {
        expect(
          (restored[key]! as num).toDouble(),
          closeTo((before[key]! as num).toDouble(), 1e-9),
          reason: key,
        );
      }
      // Rotation composed in and back out again.
      expect(((restored['rotation'] as num?) ?? 0).toDouble(), closeTo(0, 1e-9));
    });

    test('a block target re-balances with the newcomer in its slot', () {
      final document =
          EditorDocument.fromJson(
                _deck(),
              )
              .setElementMeta('el-g', {
                'block': {'kind': 'column'},
              })
              .reflowBlock('el-g');
      final moved = document.moveIntoGroup('el-loose', groupId: 'el-g', at: 2);
      final transforms = [
        for (final id in moved.childIdsOfGroup('el-g'))
          moved.elementJson(id)!['transform']! as Map<String, Object?>,
      ];
      // A three-child equal-size column: shared x, equal heights.
      expect(transforms, hasLength(3));
      final height = (transforms.first['h']! as num).toDouble();
      expect(height, lessThan(0.4));
      for (final transform in transforms) {
        expect((transform['x']! as num).toDouble(), closeTo(0.5, 1e-9));
        expect((transform['h']! as num).toDouble(), closeTo(height, 1e-9));
      }
    });

    test('refuses non-groups, groups, residents, and cross-scene moves', () {
      final document = EditorDocument.fromJson(_deck());
      expect(
        () => document.moveIntoGroup('el-loose', groupId: 'el-ga', at: 0),
        throwsArgumentError,
      );
      expect(
        () => document.moveIntoGroup('el-g', groupId: 'el-g', at: 0),
        throwsArgumentError,
      );
      expect(
        () => document.moveIntoGroup('el-ga', groupId: 'el-g', at: 0),
        throwsArgumentError,
      );
      final twoScenes = EditorDocument.fromJson(_deck()).insertElement(1, {
        'type': 'Box',
        'color': '#123456',
      }).$1;
      final stranger = twoScenes.elementIdsInScene(1).single;
      expect(
        () => twoScenes.moveIntoGroup(stranger, groupId: 'el-g', at: 0),
        throwsArgumentError,
      );
    });
  });

  group('moveOutOfGroup', () {
    test('promotes with the ungroup math so nothing moves', () {
      final document = EditorDocument.fromJson(_deck());
      final before = _absRect(document, 'el-ga');
      final moved = document.moveOutOfGroup('el-ga', at: 0);
      expect(moved.parentGroupOf('el-ga'), isNull);
      expect(moved.elementIdsInScene(0), ['el-ga', 'el-loose', 'el-g']);
      final after = _absRect(moved, 'el-ga');
      expect(after.left, closeTo(before.left, 1e-6));
      expect(after.top, closeTo(before.top, 1e-6));
      expect(after.width, closeTo(before.width, 1e-6));
    });

    test('a block source re-balances the remainder', () {
      final document =
          EditorDocument.fromJson(
                _deck(),
              )
              .setElementMeta('el-g', {
                'block': {'kind': 'column'},
              })
              .reflowBlock('el-g');
      final moved = document.moveOutOfGroup('el-ga', at: 2);
      final remaining = moved.elementJson('el-gb')!['transform']! as Map<String, Object?>;
      // A lone equal-size column child takes the whole box.
      expect((remaining['y']! as num).toDouble(), closeTo(0.5, 1e-9));
      expect((remaining['h']! as num).toDouble(), closeTo(1.0, 1e-9));
    });

    test('refuses top-level elements', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.moveOutOfGroup('el-loose', at: 0), throwsArgumentError);
    });
  });

  group('the move commands', () {
    test('each is one undo step and reports both sides affected', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const MoveIntoGroupCommand(id: 'el-loose', groupId: 'el-g', at: 2));
      expect(history.document.parentGroupOf('el-loose'), 'el-g');
      expect(history.undo(), {'el-loose', 'el-g'});
      expect(history.document.parentGroupOf('el-loose'), isNull);
      expect(
        history.document.toJson(),
        EditorDocument.fromJson(_deck()).toJson(),
      );

      history.dispatch(const MoveOutOfGroupCommand(id: 'el-ga', groupId: 'el-g', at: 0));
      expect(history.document.parentGroupOf('el-ga'), isNull);
      expect(history.undo(), {'el-ga', 'el-g'});
      expect(history.document.parentGroupOf('el-ga'), 'el-g');
    });
  });
}
