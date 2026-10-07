import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'animate': [
            {'preset': 'fadeIn', 'duration': '20f'},
          ],
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'animate': [
            {'preset': 'fadeIn', 'duration': '20f'},
          ],
        },
      ],
    },
  ],
};

void main() {
  group('SetSceneStepsCommand', () {
    test('writes the steps list onto the scene and undoes back', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetSceneStepsCommand(
            index: 0,
            steps: [
              {
                'elements': ['el-b'],
              },
            ],
          ),
        );
      expect(history.document.sceneJson(0)['steps'], [
        {
          'elements': ['el-b'],
        },
      ]);
      history.undo();
      expect(history.document.sceneJson(0).containsKey('steps'), isFalse);
    });

    test('null steps removes the key entirely', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetSceneStepsCommand(
            index: 0,
            steps: [
              {
                'elements': ['el-b'],
              },
            ],
          ),
        )
        ..dispatch(const SetSceneStepsCommand(index: 0, steps: null));
      expect(history.document.sceneJson(0).containsKey('steps'), isFalse);
    });

    test('a merge group coalesces a drag into one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetSceneStepsCommand(
            index: 0,
            steps: [
              {
                'elements': ['el-b'],
              },
            ],
            mergeGroup: 'drag-1',
          ),
        )
        ..dispatch(
          const SetSceneStepsCommand(
            index: 0,
            steps: [
              {
                'elements': ['el-a', 'el-b'],
              },
            ],
            mergeGroup: 'drag-1',
          ),
        );
      expect((history.document.sceneJson(0)['steps']! as List).first, {
        'elements': ['el-a', 'el-b'],
      });
      history.undo();
      expect(history.document.sceneJson(0).containsKey('steps'), isFalse);
      expect(history.canUndo, isFalse);
    });
  });

  group('SetAnimationAnchorTriggerCommand', () {
    test('mints the anchor on the target and points the trigger at it', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetAnimationAnchorTriggerCommand(
            id: 'el-b',
            index: 0,
            kind: 'whenEnds',
            targetId: 'el-a',
            anchorId: 'el-a',
          ),
        );
      expect(history.document.elementJson('el-a')!['anchor'], 'el-a');
      final animation = (history.document.elementJson('el-b')!['animate']! as List).first! as Map;
      expect(animation['at'], {'kind': 'whenEnds', 'anchor': 'el-a'});
      // One undo restores both the trigger and the minted anchor.
      history.undo();
      expect(history.document.elementJson('el-a')!.containsKey('anchor'), isFalse);
      final reverted = (history.document.elementJson('el-b')!['animate']! as List).first! as Map;
      expect(reverted.containsKey('at'), isFalse);
    });

    test('reuses an anchor the target already declares', () {
      final json = _deck();
      final children =
          ((json['scenes']! as List).first! as Map<String, Object?>)['children']! as List;
      (children.first! as Map<String, Object?>)['anchor'] = 'hero';
      final history = DocumentHistory(EditorDocument.fromJson(json))
        ..dispatch(
          const SetAnimationAnchorTriggerCommand(
            id: 'el-b',
            index: 0,
            kind: 'whenStarts',
            targetId: 'el-a',
            anchorId: 'hero',
          ),
        );
      expect(history.document.elementJson('el-a')!['anchor'], 'hero');
      final animation = (history.document.elementJson('el-b')!['animate']! as List).first! as Map;
      expect(animation['at'], {'kind': 'whenStarts', 'anchor': 'hero'});
    });
  });
}
