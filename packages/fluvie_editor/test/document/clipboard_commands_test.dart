import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-1',
          'type': 'Box',
          'color': '#E17055',
          'anchor': 'intro',
          'transform': {'x': 0.2, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-2',
          'type': 'Box',
          'color': '#0984E3',
          'transform': {'x': 0.8, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-3',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {
              'id': 'el-4',
              'type': 'Box',
              'color': '#6C5CE7',
              'anchor': 'nested',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  group('EditorDocument.nextIds', () {
    test('mints the requested number of distinct fresh ids', () {
      final document = EditorDocument.fromJson(_deck());
      final ids = document.nextIds(3);
      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3));
      for (final id in ids) {
        expect(document.elementJson(id), isNull);
      }
    });

    test('zero ids is an empty list', () {
      expect(EditorDocument.fromJson(_deck()).nextIds(0), isEmpty);
    });
  });

  group('EditorDocument.anchorIds', () {
    test('collects every declared anchor, nested children included', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.anchorIds, {'intro', 'nested'});
    });

    test('a deck without anchors has none', () {
      final json = _deck();
      final scenes = json['scenes']! as List<Object?>;
      for (final scene in scenes.whereType<Map<String, Object?>>()) {
        final children = scene['children']! as List<Object?>;
        for (final child in children.whereType<Map<String, Object?>>()) {
          child.remove('anchor');
          final nested = child['children'];
          if (nested is List<Object?>) {
            for (final grandchild in nested.whereType<Map<String, Object?>>()) {
              grandchild.remove('anchor');
            }
          }
        }
      }
      expect(EditorDocument.fromJson(json).anchorIds, isEmpty);
    });
  });

  group('InsertElementsCommand', () {
    test('appends every element in order as one step', () {
      final document = EditorDocument.fromJson(_deck());
      const command = InsertElementsCommand(
        scene: 0,
        elements: [
          {'id': 'el-a', 'type': 'Box', 'color': '#FFFFFF'},
          {'id': 'el-b', 'type': 'Box', 'color': '#000000'},
        ],
      );
      final next = command.apply(document);
      expect(next.elementIdsInScene(0), ['el-1', 'el-2', 'el-a', 'el-b']);
      expect(command.affectedIds, {'el-a', 'el-b'});
      expect(command.label, 'Paste 2 elements');
    });

    test('one element reads singular and a verb overrides the label', () {
      const paste = InsertElementsCommand(
        scene: 0,
        elements: [
          {'id': 'el-a', 'type': 'Box', 'color': '#FFFFFF'},
        ],
      );
      expect(paste.label, 'Paste element');
      const duplicate = InsertElementsCommand(
        scene: 0,
        verb: 'Duplicate',
        elements: [
          {'id': 'el-a', 'type': 'Box', 'color': '#FFFFFF'},
        ],
      );
      expect(duplicate.label, 'Duplicate element');
    });

    test('undo through the history restores the original children', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const InsertElementsCommand(
            scene: 0,
            elements: [
              {'id': 'el-a', 'type': 'Box', 'color': '#FFFFFF'},
            ],
          ),
        );
      expect(history.document.elementIdsInScene(0), ['el-1', 'el-2', 'el-a']);
      history.undo();
      expect(history.document.elementIdsInScene(0), ['el-1', 'el-2']);
    });
  });

  group('InsertElementsCommand into an entered group', () {
    test('non-group elements nest but a group lands at the scene top level', () {
      final document = EditorDocument.fromJson(_deck());
      const command = InsertElementsCommand(
        scene: 1,
        group: 'el-3',
        elements: [
          {
            'id': 'ins-box',
            'type': 'Box',
            'color': '#FFFFFF',
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
          },
          {
            'id': 'ins-grp',
            'type': 'Group',
            'transform': {'x': 0.3, 'y': 0.3, 'w': 0.3, 'h': 0.3},
            'children': [
              {
                'id': 'ins-grp-c',
                'type': 'Box',
                'color': '#000000',
                'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
              },
            ],
          },
        ],
      );
      final next = command.apply(document);
      // The box nests inside the entered group (existing behavior holds).
      expect(next.childIdsOfGroup('el-3'), ['el-4', 'ins-box']);
      expect(next.parentGroupOf('ins-box'), 'el-3');
      // The group lands beside el-3 at the scene's top level, never nested.
      expect(next.parentGroupOf('ins-grp'), isNull);
      expect(next.elementIdsInScene(1), ['el-3', 'ins-grp']);
      // The whole mixed batch is one command (one undo step).
      expect(command.affectedIds, {'ins-box', 'ins-grp'});
    });

    test('every element nests when none is a group', () {
      final document = EditorDocument.fromJson(_deck());
      const command = InsertElementsCommand(
        scene: 1,
        group: 'el-3',
        elements: [
          {
            'id': 'ins-box',
            'type': 'Box',
            'color': '#FFFFFF',
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
          },
        ],
      );
      expect(command.apply(document).childIdsOfGroup('el-3'), ['el-4', 'ins-box']);
    });
  });

  group('RemoveElementsCommand', () {
    test('removes the whole selection in one step', () {
      final document = EditorDocument.fromJson(_deck());
      const command = RemoveElementsCommand(ids: ['el-1', 'el-2']);
      final next = command.apply(document);
      expect(next.elementIdsInScene(0), isEmpty);
      expect(command.affectedIds, {'el-1', 'el-2'});
      expect(command.label, 'Delete 2 elements');
    });

    test('a single id reads singular and undoes as one step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      const command = RemoveElementsCommand(ids: ['el-1']);
      expect(command.label, 'Delete el-1');
      history.dispatch(command);
      expect(history.document.elementIdsInScene(0), ['el-2']);
      history.undo();
      expect(history.document.elementIdsInScene(0), ['el-1', 'el-2']);
    });

    test('nested ids remove from their group', () {
      final document = EditorDocument.fromJson(_deck());
      const command = RemoveElementsCommand(ids: ['el-4']);
      expect(command.apply(document).childIdsOfGroup('el-3'), isEmpty);
    });
  });
}
