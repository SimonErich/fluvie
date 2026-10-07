import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'masters': {
    'base': {
      'children': [
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.25, 'w': 0.5, 'h': 0.3},
        },
        {'type': 'Placeholder', 'slot': 'media'},
      ],
    },
  },
  'scenes': [
    {
      'duration': '60f',
      'master': 'base',
      'fills': {
        'title': {'id': 'el-fill', 'type': 'Text', 'text': 'Hello'},
      },
      'children': [
        {
          'id': 'el-over',
          'type': 'Box',
          'color': '#0984E3',
          'transform': {'x': 0.5, 'y': 0.25, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
  ],
};

void main() {
  group('fills in SceneGeometry', () {
    test('a fill resolves through the placeholder placement and is hittable', () {
      final geometry = SceneGeometry.of(EditorDocument.fromJson(_deck()), 0);
      final rect = geometry.rectOf('el-fill');
      expect(rect, isNotNull);
      expect(rect!.center.dx, closeTo(160, 0.001));
      expect(rect.center.dy, closeTo(45, 0.001));
      // Left of the overlapping scene child: the fill takes the hit.
      expect(geometry.hitTest(const Offset(90, 45)), 'el-fill');
    });

    test('a scene child sits above a fill at the same spot', () {
      final geometry = SceneGeometry.of(EditorDocument.fromJson(_deck()), 0);
      expect(geometry.hitTest(const Offset(160, 45)), 'el-over');
    });

    test('a fill transform beats the placeholder placement', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).setTransform('el-fill', {'x': 0.5, 'y': 0.75, 'w': 0.5, 'h': 0.3});
      final geometry = SceneGeometry.of(document, 0);
      expect(geometry.rectOf('el-fill')!.center.dy, closeTo(135, 0.001));
    });

    test('unfilled slots and transformless fills stay out of the geometry', () {
      final document = EditorDocument.fromJson(_deck()).fillSlot(0, 'media', {
        'id': 'el-media',
        'type': 'Image',
        'source': {'kind': 'asset', 'value': 'a.png'},
      });
      final geometry = SceneGeometry.of(document, 0);
      // The media placeholder has no transform and neither has its fill.
      expect(geometry.rectOf('el-media'), isNull);
    });

    test('an entered group scopes fills out entirely', () {
      final deck = _deck();
      ((deck['scenes']! as List)[0]! as Map<String, Object?>)['children'] = [
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {
              'id': 'el-gc',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
            },
          ],
        },
      ];
      final geometry = SceneGeometry.of(
        EditorDocument.fromJson(deck),
        0,
        enteredGroup: 'el-g',
      );
      expect(geometry.rectOf('el-fill'), isNull);
      expect(geometry.rectOf('el-gc'), isNotNull);
    });
  });
}
