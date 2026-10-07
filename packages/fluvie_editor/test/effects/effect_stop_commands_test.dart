// Editing a keyframed effect parameter's stops: insert at a frame, move by
// writing the whole positions list, and remove — which at the two-stop
// minimum collapses the parameter back to the literal it would read.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({Object? amount, List<Object?>? easings}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-fx',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'show': {'from': '0f', 'to': '60f'},
          'effects': [
            {'kind': 'grain', 'amount': 0.2},
            {
              'kind': 'vignette',
              'amount':
                  amount ??
                  {
                    'values': [0, 0.9],
                    'positions': ['0f', '60f'],
                    'easings': ?easings,
                  },
            },
          ],
        },
      ],
    },
  ],
};

Map<String, Object?> _effect(EditorDocument document, {int index = 1}) =>
    ((document.elementJson('el-fx')!['effects']! as List)[index]! as Map).cast<String, Object?>();

Map<String, Object?> _param(EditorDocument document) =>
    (_effect(document)['amount']! as Map).cast<String, Object?>();

void main() {
  group('updateEffect', () {
    test('merges a patch into one effect and leaves the rest alone', () {
      final next = EditorDocument.fromJson(
        _deck(),
      ).updateEffect('el-fx', 0, {'amount': 0.5});

      expect(_effect(next, index: 0)['amount'], 0.5);
      expect(_param(next)['values'], [0, 0.9]);
    });

    test('a null value removes its key', () {
      final next = EditorDocument.fromJson(
        _deck(),
      ).updateEffect('el-fx', 0, {'amount': null});

      expect(_effect(next, index: 0).containsKey('amount'), isFalse);
    });

    test('refuses an unknown element and a missing effect index', () {
      final document = EditorDocument.fromJson(_deck());

      expect(() => document.updateEffect('nobody', 0, {}), throwsArgumentError);
      expect(() => document.updateEffect('el-fx', 9, {}), throwsRangeError);
    });
  });

  group('InsertEffectStopCommand', () {
    const command = InsertEffectStopCommand(
      id: 'el-fx',
      index: 1,
      param: 'amount',
      stop: 1,
      value: 0.45,
      positionFrames: [0, 30, 60],
    );

    test('inserts the value and writes every position in frames form', () {
      final next = command.apply(EditorDocument.fromJson(_deck()));

      expect(_param(next)['values'], [0, 0.45, 0.9]);
      expect(_param(next)['positions'], ['0f', '30f', '60f']);
      expect(_param(next).containsKey('easings'), isFalse);
      expect(command.label, contains('el-fx'));
    });

    test('splits the segment easing so the curve keeps its authored shape', () {
      final next = command.apply(EditorDocument.fromJson(_deck(easings: ['smooth'])));

      expect(_param(next)['easings'], ['smooth', 'smooth']);
    });

    test('undo restores the document exactly', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final before = history.document.toJson();

      history
        ..dispatch(command)
        ..undo();

      expect(history.document.toJson(), before);
    });
  });

  group('SetEffectStopPositionsCommand', () {
    test('writes the full positions list in frames form', () {
      const command = SetEffectStopPositionsCommand(
        id: 'el-fx',
        index: 1,
        param: 'amount',
        positionFrames: [0, 45],
      );
      final next = command.apply(EditorDocument.fromJson(_deck()));

      expect(_param(next)['positions'], ['0f', '45f']);
      expect(_param(next)['values'], [0, 0.9]);
    });

    test('drags coalesce into one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final before = history.document.toJson();

      history
        ..dispatch(
          const SetEffectStopPositionsCommand(
            id: 'el-fx',
            index: 1,
            param: 'amount',
            positionFrames: [0, 40],
            mergeGroup: 'drag-1',
          ),
        )
        ..dispatch(
          const SetEffectStopPositionsCommand(
            id: 'el-fx',
            index: 1,
            param: 'amount',
            positionFrames: [0, 45],
            mergeGroup: 'drag-1',
          ),
        )
        ..undo();

      expect(history.document.toJson(), before);
    });
  });

  group('RemoveEffectStopCommand', () {
    test('removes the stop, its position, and its outgoing easing segment', () {
      final document = EditorDocument.fromJson(
        _deck(
          amount: {
            'values': [0, 0.5, 0.9],
            'positions': ['0f', '30f', '60f'],
            'easings': ['smooth', 'bounce'],
          },
        ),
      );
      const command = RemoveEffectStopCommand(id: 'el-fx', index: 1, param: 'amount', stop: 1);
      final next = command.apply(document);

      expect(_param(next)['values'], [0, 0.9]);
      expect(_param(next)['positions'], ['0f', '60f']);
      // The removed stop takes its outgoing segment with it — the same
      // discipline animation keyframes follow.
      expect(_param(next)['easings'], ['smooth']);
    });

    test('the last stop drops its incoming segment instead', () {
      final document = EditorDocument.fromJson(
        _deck(
          amount: {
            'values': [0, 0.5, 0.9],
            'positions': ['0f', '30f', '60f'],
            'easings': ['smooth', 'bounce'],
          },
        ),
      );
      const command = RemoveEffectStopCommand(id: 'el-fx', index: 1, param: 'amount', stop: 2);
      final next = command.apply(document);

      expect(_param(next)['values'], [0, 0.5]);
      expect(_param(next)['easings'], ['smooth']);
    });

    test('at the two-stop minimum it collapses the parameter to a literal', () {
      // Deleting the ramp's first stop leaves the value the parameter would
      // hold from then on: the surviving stop's, as a plain number.
      const command = RemoveEffectStopCommand(id: 'el-fx', index: 1, param: 'amount', stop: 0);
      final next = command.apply(EditorDocument.fromJson(_deck()));

      expect(_effect(next)['amount'], 0.9);
    });

    test('undo restores the collapsed parameter exactly', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final before = history.document.toJson();

      history
        ..dispatch(const RemoveEffectStopCommand(id: 'el-fx', index: 1, param: 'amount', stop: 0))
        ..undo();

      expect(history.document.toJson(), before);
    });
  });
}
