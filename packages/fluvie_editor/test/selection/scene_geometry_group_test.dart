import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({bool bareGroup = false}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-x',
          'type': 'Box',
          'color': '#101018',
          'transform': {'x': 0.9, 'y': 0.5, 'w': 0.1, 'h': 0.2},
        },
        {
          'id': 'el-g',
          'type': 'Group',
          if (!bareGroup) 'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {
              'id': 'el-ga',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.25, 'y': 0.5, 'w': 0.5, 'h': 1.0},
            },
            {
              'id': 'el-gb',
              'type': 'Box',
              'color': '#2ECC8F',
              'transform': {'x': 0.75, 'y': 0.5, 'w': 0.5, 'h': 1.0, 'rotation': 15},
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  group('outside a group (E15: one unit)', () {
    test('a point over a child hits the group itself', () {
      final doc = EditorDocument.fromJson(_deck());
      final geometry = SceneGeometry.of(doc, 0);
      expect(geometry.hitTest(const Offset(100, 90)), 'el-g');
      expect(geometry.rectOf('el-ga'), isNull);
    });
  });

  group('an entered group', () {
    test('children resolve to absolute canvas rects', () {
      final doc = EditorDocument.fromJson(_deck());
      final geometry = SceneGeometry.of(doc, 0, enteredGroup: 'el-g');
      expect(geometry.rectOf('el-ga'), const Rect.fromLTRB(80, 45, 160, 135));
      expect(geometry.rectOf('el-gb'), const Rect.fromLTRB(160, 45, 240, 135));
      expect(geometry.rotationOf('el-gb'), 15);
    });

    test('hit-testing targets the children, not the group or outsiders', () {
      final doc = EditorDocument.fromJson(_deck());
      final geometry = SceneGeometry.of(doc, 0, enteredGroup: 'el-g');
      expect(geometry.hitTest(const Offset(100, 90)), 'el-ga');
      expect(geometry.hitTest(const Offset(200, 90)), 'el-gb');
      // el-x lives at (288, 90) — outside the entered scope.
      expect(geometry.hitTest(const Offset(288, 90)), isNull);
    });

    test('the marquee sweeps children in absolute space', () {
      final doc = EditorDocument.fromJson(_deck());
      final geometry = SceneGeometry.of(doc, 0, enteredGroup: 'el-g');
      expect(
        geometry.hitTestMarquee(const Rect.fromLTRB(70, 40, 250, 140)),
        {'el-ga', 'el-gb'},
      );
    });

    test('a group without a transform frames the whole canvas', () {
      final doc = EditorDocument.fromJson(_deck(bareGroup: true));
      final geometry = SceneGeometry.of(doc, 0, enteredGroup: 'el-g');
      expect(geometry.rectOf('el-ga'), const Rect.fromLTRB(0, 0, 160, 180));
    });

    test('an unknown or non-group id falls back to the top level', () {
      final doc = EditorDocument.fromJson(_deck());
      final geometry = SceneGeometry.of(doc, 0, enteredGroup: 'el-x');
      expect(geometry.hitTest(const Offset(100, 90)), 'el-g');
    });
  });

  group('groupFrameRect', () {
    test('resolves the group box in canvas pixels', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(groupFrameRect(doc, 'el-g'), const Rect.fromLTRB(80, 45, 240, 135));
    });

    test('a bare group frames the whole canvas', () {
      final doc = EditorDocument.fromJson(_deck(bareGroup: true));
      expect(groupFrameRect(doc, 'el-g'), const Rect.fromLTRB(0, 0, 320, 180));
    });

    test('null for non-groups and unknown ids', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(groupFrameRect(doc, 'el-x'), isNull);
      expect(groupFrameRect(doc, 'missing'), isNull);
    });

    test('an unsized transform resolves like the expand it renders as', () {
      final json = _deck();
      final scene = (json['scenes']! as List).first as Map<String, Object?>;
      final group = (scene['children']! as List).last as Map<String, Object?>;
      group['transform'] = {'x': 0.5, 'y': 0.5};
      final doc = EditorDocument.fromJson(json);
      expect(groupFrameRect(doc, 'el-g'), const Rect.fromLTRB(0, 0, 320, 180));
    });
  });
}
