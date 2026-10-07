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
        {
          'id': 'el-a',
          'type': 'Box',
          'color': '#E17055',
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'color': '#0984E3',
          'transform': {'x': 0.75, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.8, 'w': 0.4, 'h': 0.2},
          'children': [
            {
              'id': 'el-ga',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
            },
          ],
        },
      ],
    },
  ],
  'editor': {
    'editorSchema': 1,
    'elements': {
      'el-g': {
        'block': {'kind': 'row'},
      },
    },
  },
};

void main() {
  group('the make-block commands', () {
    test('wrap the selection at its bounding box and select the block', () async {
      final document = EditorDocument.fromJson(_deck());
      final dispatched = <EditorCommand>[];
      Set<String>? selected;
      final scope = CommandScope(
        document: document,
        slide: 0,
        selection: const {'el-a', 'el-b'},
        dispatch: dispatched.add,
        select: (ids) => selected = ids,
        rectOf: SceneGeometry.of(document, 0).rectOf,
      );
      await editorCommandById('block.grid').execute(scope);
      final command = dispatched.single as MakeBlockCommand;
      expect(command.block.kind, BlockKind.grid);
      expect(command.ids, ['el-a', 'el-b']);
      expect(command.groupId, 'el-1');
      // The union of the two boxes: x 0.15..0.85, y 0.4..0.6.
      expect((command.transform['x']! as num).toDouble(), closeTo(0.5, 1e-9));
      expect((command.transform['y']! as num).toDouble(), closeTo(0.5, 1e-9));
      expect((command.transform['w']! as num).toDouble(), closeTo(0.7, 1e-9));
      expect((command.transform['h']! as num).toDouble(), closeTo(0.2, 1e-9));
      expect(selected, {'el-1'});
    });

    test('every kind has its own command', () async {
      for (final kind in BlockKind.values) {
        final entry = editorCommandById('block.${kind.name}');
        expect(entry.title, 'Make ${kind.label} block');
      }
    });

    test('without resolved geometry nothing dispatches', () async {
      final document = EditorDocument.fromJson(_deck());
      final dispatched = <EditorCommand>[];
      final scope = CommandScope(
        document: document,
        slide: 0,
        selection: const {'el-a', 'el-b'},
        dispatch: dispatched.add,
      );
      await editorCommandById('block.row').execute(scope);
      expect(dispatched, isEmpty);
    });
  });

  group('the clear-block command', () {
    test('clears every selected block group in one command', () async {
      final document = EditorDocument.fromJson(_deck());
      final dispatched = <EditorCommand>[];
      final scope = CommandScope(
        document: document,
        slide: 0,
        selection: const {'el-g', 'el-a'},
        dispatch: dispatched.add,
      );
      await editorCommandById('block.clear').execute(scope);
      final command = dispatched.single as ClearBlockCommand;
      expect(command.ids, ['el-g']);
    });
  });
}
