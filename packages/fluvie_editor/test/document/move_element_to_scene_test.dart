import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '120f',
      'steps': [
        {
          'elements': ['el-clip'],
        },
        {
          'elements': ['el-a', 'el-b'],
        },
      ],
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
        {
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
          'show': {'from': '10f', 'to': '50f'},
          'animate': [
            {'preset': 'fadeIn'},
          ],
        },
        {
          'id': 'el-group',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.6, 'h': 0.6},
          'show': {'from': '0f', 'to': '40f'},
          'children': [
            {'id': 'el-child', 'type': 'Text', 'text': 'inside'},
          ],
        },
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-far', 'type': 'Text', 'text': 'far'},
      ],
    },
  ],
};

void main() {
  late EditorDocument document;

  setUp(() => document = EditorDocument.fromJson(_deck()));

  group('MoveElementToSceneCommand', () {
    test('moves the element verbatim and rewrites only its show window', () {
      const command = MoveElementToSceneCommand(
        id: 'el-clip',
        toScene: 1,
        fromFrames: 20,
        toFrames: 60,
      );
      final next = command.apply(document);
      expect(next.sceneOfElement('el-clip'), 1);
      // Appended on top of the target scene's z-order.
      expect(next.elementIdsInScene(1), ['el-far', 'el-clip']);
      final moved = next.elementJson('el-clip')!;
      expect(moved['show'], {'from': '20f', 'to': '60f'});
      // Everything else travels verbatim.
      expect(moved['transform'], {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4});
      expect(moved['animate'], [
        {'preset': 'fadeIn'},
      ]);
      expect(moved['source'], {'kind': 'asset', 'value': 'clips/broll.mp4'});
    });

    test('strips the moved id from the source scene steps, dropping emptied steps', () {
      const command = MoveElementToSceneCommand(
        id: 'el-clip',
        toScene: 1,
        fromFrames: 0,
        toFrames: 40,
      );
      final next = command.apply(document);
      // The step that held only el-clip is gone; the other stays intact.
      expect(next.sceneJson(0)['steps'], [
        {
          'elements': ['el-a', 'el-b'],
        },
      ]);
    });

    test('removes the steps key when the last step empties', () {
      final trimmed = document.toJson();
      ((trimmed['scenes']! as List)[0]! as Map<String, Object?>)['steps'] = [
        {
          'elements': ['el-clip'],
        },
      ];
      const command = MoveElementToSceneCommand(
        id: 'el-clip',
        toScene: 1,
        fromFrames: 0,
        toFrames: 40,
      );
      final next = command.apply(EditorDocument.fromJson(trimmed));
      expect(next.sceneJson(0).containsKey('steps'), isFalse);
    });

    test('a group moves whole, its children riding along', () {
      const command = MoveElementToSceneCommand(
        id: 'el-group',
        toScene: 1,
        fromFrames: 10,
        toFrames: 50,
      );
      final next = command.apply(document);
      expect(next.sceneOfElement('el-group'), 1);
      expect(next.childIdsOfGroup('el-group'), ['el-child']);
      expect(next.sceneOfElement('el-child'), 1);
      expect(next.elementJson('el-group')!['show'], {'from': '10f', 'to': '50f'});
    });

    test('refuses a group child, an unknown id, and a same-scene move', () {
      const child = MoveElementToSceneCommand(
        id: 'el-child',
        toScene: 1,
        fromFrames: 0,
        toFrames: 10,
      );
      expect(() => child.apply(document), throwsArgumentError);
      const unknown = MoveElementToSceneCommand(
        id: 'nope',
        toScene: 1,
        fromFrames: 0,
        toFrames: 10,
      );
      expect(() => unknown.apply(document), throwsArgumentError);
      const same = MoveElementToSceneCommand(
        id: 'el-clip',
        toScene: 0,
        fromFrames: 0,
        toFrames: 10,
      );
      expect(() => same.apply(document), throwsArgumentError);
    });

    test('one undo step restores everything, the source scene steps included', () {
      final before = document.toJson();
      final history = DocumentHistory(document)
        ..dispatch(
          const MoveElementToSceneCommand(id: 'el-clip', toScene: 1, fromFrames: 20, toFrames: 60),
        );
      expect(history.document.sceneOfElement('el-clip'), 1);
      final affected = history.undo();
      expect(affected, {'el-clip'});
      expect(history.document.toJson(), before);
    });

    test('a drag that crosses the boundary coalesces with its in-scene stream', () {
      final before = document.toJson();
      final history = DocumentHistory(document)
        ..dispatch(
          const SetShowWindowCommand(id: 'el-clip', fromFrames: 30, toFrames: 70, mergeGroup: 'd'),
        )
        ..dispatch(
          const MoveElementToSceneCommand(
            id: 'el-clip',
            toScene: 1,
            fromFrames: 5,
            toFrames: 45,
            mergeGroup: 'd',
          ),
        );
      expect(history.document.sceneOfElement('el-clip'), 1);
      history.undo();
      // One step: the whole drag lands back on the pre-drag document.
      expect(history.document.toJson(), before);
      expect(history.canUndo, isFalse);
    });

    test('carries an honest label naming the target slide', () {
      const command = MoveElementToSceneCommand(
        id: 'el-clip',
        toScene: 1,
        fromFrames: 0,
        toFrames: 40,
      );
      expect(command.label, 'Move el-clip to slide 2');
      expect(command.affectedIds, {'el-clip'});
      expect(command.mergeKey, isNull);
    });
  });
}
