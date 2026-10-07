import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({List<Map<String, Object?>>? animate}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-k',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'animate':
              animate ??
              [
                {
                  'keyframes': [
                    {'opacity': 0},
                    {'x': 0.5},
                    <String, Object?>{},
                  ],
                  'easings': ['smooth', 'bounce'],
                  'duration': '30f',
                },
                {'preset': 'fadeOut', 'duration': '20f'},
              ],
        },
      ],
    },
  ],
};

Map<String, Object?> _animation(EditorDocument document, {int index = 0}) =>
    ((document.elementJson('el-k')!['animate']! as List)[index]! as Map).cast<String, Object?>();

void main() {
  group('SetKeyframePositionsCommand', () {
    test('writes the full positions list in frames form', () {
      const command = SetKeyframePositionsCommand(
        id: 'el-k',
        index: 0,
        positionFrames: [0, 20, 30],
      );
      final next = command.apply(EditorDocument.fromJson(_deck()));
      expect(_animation(next)['positions'], ['0f', '20f', '30f']);
      expect(command.label, contains('el-k'));
      expect(command.affectedIds, {'el-k'});
      expect(command.mergeKey, isNull);
    });

    test('a drag coalesces through its merge group into one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetKeyframePositionsCommand(
            id: 'el-k',
            index: 0,
            positionFrames: [0, 18, 30],
            mergeGroup: 'd1',
          ),
        )
        ..dispatch(
          const SetKeyframePositionsCommand(
            id: 'el-k',
            index: 0,
            positionFrames: [0, 22, 30],
            mergeGroup: 'd1',
          ),
        );
      expect(_animation(history.document)['positions'], ['0f', '22f', '30f']);
      history.undo();
      expect(_animation(history.document).containsKey('positions'), isFalse);
      expect(history.canUndo, isFalse);
    });
  });

  group('InsertKeyframeStopCommand', () {
    test('splices the stop, duplicates the split segment easing, writes positions', () {
      const command = InsertKeyframeStopCommand(
        id: 'el-k',
        index: 0,
        stop: 2,
        keyframe: {'x': 0.25},
        positionFrames: [0, 15, 20, 30],
      );
      final next = command.apply(EditorDocument.fromJson(_deck()));
      final animation = _animation(next);
      expect(animation['keyframes'], [
        {'opacity': 0},
        {'x': 0.5},
        {'x': 0.25},
        <String, Object?>{},
      ]);
      expect(animation['easings'], ['smooth', 'bounce', 'bounce']);
      expect(animation['positions'], ['0f', '15f', '20f', '30f']);
      expect(command.label, contains('el-k'));
      expect(command.affectedIds, {'el-k'});
    });

    test('inserting first duplicates the first easing; without easings none appear', () {
      const first = InsertKeyframeStopCommand(
        id: 'el-k',
        index: 0,
        stop: 0,
        keyframe: {'opacity': 0},
        positionFrames: [2, 5, 15, 30],
      );
      final next = first.apply(EditorDocument.fromJson(_deck()));
      expect(_animation(next)['easings'], ['smooth', 'smooth', 'bounce']);

      final bare =
          const InsertKeyframeStopCommand(
            id: 'el-k',
            index: 0,
            stop: 1,
            keyframe: {'opacity': 0.5},
            positionFrames: [0, 10, 15, 30],
          ).apply(
            EditorDocument.fromJson(
              _deck(
                animate: [
                  {
                    'keyframes': [
                      {'opacity': 0},
                      <String, Object?>{},
                    ],
                    'duration': '30f',
                  },
                ],
              ),
            ),
          );
      final animation = _animation(bare);
      expect(animation.containsKey('easings'), isFalse);
      expect(animation['keyframes']! as List, hasLength(3));
    });

    test('undo removes the stop again in one step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const InsertKeyframeStopCommand(
            id: 'el-k',
            index: 0,
            stop: 1,
            keyframe: {'opacity': 0.5},
            positionFrames: [0, 8, 15, 30],
          ),
        );
      expect(_animation(history.document)['keyframes']! as List, hasLength(4));
      history.undo();
      expect(_animation(history.document)['keyframes']! as List, hasLength(3));
      expect(_animation(history.document).containsKey('positions'), isFalse);
    });
  });

  group('RemoveKeyframeStopCommand', () {
    test('removes the stop with its outgoing easing segment and position', () {
      final seeded = const SetKeyframePositionsCommand(
        id: 'el-k',
        index: 0,
        positionFrames: [0, 12, 30],
      ).apply(EditorDocument.fromJson(_deck()));
      const command = RemoveKeyframeStopCommand(id: 'el-k', index: 0, stop: 1);
      final next = command.apply(seeded);
      final animation = _animation(next);
      expect(animation['keyframes'], [
        {'opacity': 0},
        <String, Object?>{},
      ]);
      expect(animation['easings'], ['smooth']);
      expect(animation['positions'], ['0f', '30f']);
      expect(command.label, contains('el-k'));
      expect(command.affectedIds, {'el-k'});
    });

    test('the last stop drops its incoming segment instead', () {
      final next = const RemoveKeyframeStopCommand(
        id: 'el-k',
        index: 0,
        stop: 2,
      ).apply(EditorDocument.fromJson(_deck()));
      final animation = _animation(next);
      expect(animation['keyframes'], [
        {'opacity': 0},
        {'x': 0.5},
      ]);
      expect(animation['easings'], ['smooth']);
      expect(animation.containsKey('positions'), isFalse);
    });
  });

  group('SetKeyframeStopCommand', () {
    test('replaces one stop and coalesces per field group', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetKeyframeStopCommand(
            id: 'el-k',
            index: 0,
            stop: 1,
            keyframe: {'x': 0.6},
            mergeGroup: 'kf-x',
          ),
        )
        ..dispatch(
          const SetKeyframeStopCommand(
            id: 'el-k',
            index: 0,
            stop: 1,
            keyframe: {'x': 0.8},
            mergeGroup: 'kf-x',
          ),
        );
      expect((_animation(history.document)['keyframes']! as List)[1], {'x': 0.8});
      history.undo();
      expect((_animation(history.document)['keyframes']! as List)[1], {'x': 0.5});
      expect(history.canUndo, isFalse);
    });
  });

  group('SetKeyframeEasingCommand', () {
    test('writes one segment easing', () {
      const command = SetKeyframeEasingCommand(id: 'el-k', index: 0, segment: 1, easing: 'elastic');
      final next = command.apply(EditorDocument.fromJson(_deck()));
      expect(_animation(next)['easings'], ['smooth', 'elastic']);
      expect(command.affectedIds, {'el-k'});
    });

    test('mints a linear easings list when the form had none', () {
      final bare = EditorDocument.fromJson(
        _deck(
          animate: [
            {
              'keyframes': [<String, Object?>{}, <String, Object?>{}, <String, Object?>{}],
              'duration': '30f',
            },
          ],
        ),
      );
      final next = const SetKeyframeEasingCommand(
        id: 'el-k',
        index: 0,
        segment: 1,
        easing: 'bounce',
      ).apply(bare);
      expect(_animation(next)['easings'], ['linear', 'bounce']);
    });
  });

  group('RemoveAnimationCommand', () {
    test('removes the indexed animation', () {
      const command = RemoveAnimationCommand(id: 'el-k', index: 1);
      final next = command.apply(EditorDocument.fromJson(_deck()));
      final animate = next.elementJson('el-k')!['animate']! as List;
      expect(animate, hasLength(1));
      expect(command.label, contains('el-k'));
      expect(command.affectedIds, {'el-k'});
    });

    test('removing the last animation drops the animate key, undo restores it', () {
      final history = DocumentHistory(
        EditorDocument.fromJson(
          _deck(
            animate: [
              {'preset': 'fadeIn', 'duration': '30f'},
            ],
          ),
        ),
      )..dispatch(const RemoveAnimationCommand(id: 'el-k', index: 0));
      expect(history.document.elementJson('el-k')!.containsKey('animate'), isFalse);
      history.undo();
      expect(history.document.elementJson('el-k')!['animate'], hasLength(1));
    });
  });

  group('SetAnimationEaseCommand', () {
    test('writes and clears the ease', () {
      const command = SetAnimationEaseCommand(id: 'el-k', index: 1, ease: 'snappy');
      final next = command.apply(EditorDocument.fromJson(_deck()));
      expect(_animation(next, index: 1)['ease'], 'snappy');
      final cleared = const SetAnimationEaseCommand(id: 'el-k', index: 1, ease: null).apply(next);
      expect(_animation(cleared, index: 1).containsKey('ease'), isFalse);
      expect(command.affectedIds, {'el-k'});
      expect(command.label, contains('el-k'));
    });
  });

  group('SetAnimationTriggerCommand', () {
    test('writes the simple trigger forms and clears back to auto', () {
      const command = SetAnimationTriggerCommand(id: 'el-k', index: 1, trigger: 'previous');
      final next = command.apply(EditorDocument.fromJson(_deck()));
      expect(_animation(next, index: 1)['at'], 'previous');
      final cleared = const SetAnimationTriggerCommand(
        id: 'el-k',
        index: 1,
        trigger: null,
      ).apply(next);
      expect(_animation(cleared, index: 1).containsKey('at'), isFalse);
      expect(command.affectedIds, {'el-k'});
      expect(command.label, contains('el-k'));
    });
  });

  group('a keyframes trim rescales authored positions with the duration', () {
    test('SetAnimationDurationCommand carries the rescaled positions', () {
      final seeded = const SetKeyframePositionsCommand(
        id: 'el-k',
        index: 0,
        positionFrames: [0, 15, 30],
      ).apply(EditorDocument.fromJson(_deck()));
      const command = SetAnimationDurationCommand(
        id: 'el-k',
        index: 0,
        durationFrames: 60,
        positionFrames: [0, 30, 60],
      );
      final next = command.apply(seeded);
      final animation = _animation(next);
      expect(animation['duration'], '60f');
      expect(animation['positions'], ['0f', '30f', '60f']);
    });
  });

  group('removeAnimation guards its input', () {
    test('an index past the animate list throws', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.removeAnimation('el-k', 5), throwsRangeError);
    });

    test('an unknown element throws', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.removeAnimation('nope', 0), throwsArgumentError);
    });
  });
}
