// The Effects tab's verbs: add an effect, remove one, reorder the stack,
// toggle enabled, and write one parameter — literal or keyframed, which is
// how the stopwatch converts in both directions. Each is one undo step.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({List<Object?>? effects}) => {
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
          'effects': ?effects,
        },
      ],
    },
  ],
};

List<Object?> _effects(EditorDocument document) =>
    document.elementJson('el-fx')!['effects']! as List;

Map<String, Object?> _effect(EditorDocument document, int index) =>
    (_effects(document)[index]! as Map).cast<String, Object?>();

void main() {
  group('AddEffectCommand', () {
    test('appends to the stack, creating the list on a bare element', () {
      const command = AddEffectCommand(id: 'el-fx', effect: {'kind': 'grain', 'amount': 0.3});
      final next = command.apply(EditorDocument.fromJson(_deck()));

      expect(_effects(next), hasLength(1));
      expect(_effect(next, 0)['kind'], 'grain');
      expect(command.label, contains('grain'));
    });

    test('appends after what is already there', () {
      final next =
          const AddEffectCommand(
            id: 'el-fx',
            effect: {'kind': 'bloom'},
          ).apply(
            EditorDocument.fromJson(
              _deck(
                effects: [
                  {'kind': 'grain'},
                ],
              ),
            ),
          );

      expect(_effects(next).length, 2);
      expect(_effect(next, 1)['kind'], 'bloom');
    });

    test('undo removes it again', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final before = history.document.toJson();

      history
        ..dispatch(const AddEffectCommand(id: 'el-fx', effect: {'kind': 'grain'}))
        ..undo();

      expect(history.document.toJson(), before);
    });
  });

  group('RemoveEffectCommand', () {
    test('removes one entry; removing the last drops the key itself', () {
      final document = EditorDocument.fromJson(
        _deck(
          effects: [
            {'kind': 'grain'},
            {'kind': 'bloom'},
          ],
        ),
      );

      final one = const RemoveEffectCommand(id: 'el-fx', index: 0).apply(document);
      expect(_effect(one, 0)['kind'], 'bloom');

      final none = const RemoveEffectCommand(id: 'el-fx', index: 0).apply(one);
      expect(none.elementJson('el-fx')!.containsKey('effects'), isFalse);
    });
  });

  group('ReorderEffectCommand', () {
    test('moves an entry to a new index, keeping the rest in order', () {
      final document = EditorDocument.fromJson(
        _deck(
          effects: [
            {'kind': 'grain'},
            {'kind': 'bloom'},
            {'kind': 'vignette'},
          ],
        ),
      );
      const command = ReorderEffectCommand(id: 'el-fx', from: 0, to: 2);
      final next = command.apply(document);

      expect(
        [for (var i = 0; i < 3; i++) _effect(next, i)['kind']],
        ['bloom', 'vignette', 'grain'],
      );
    });
  });

  group('SetEffectEnabledCommand', () {
    test('turns an effect off and on, in the document form', () {
      final document = EditorDocument.fromJson(
        _deck(
          effects: [
            {'kind': 'grain'},
          ],
        ),
      );

      final off = const SetEffectEnabledCommand(
        id: 'el-fx',
        index: 0,
        enabled: false,
      ).apply(document);
      expect(_effect(off, 0)['enabled'], false);

      // Back on drops the key: true is the default and the document says
      // only what a default would not.
      final on = const SetEffectEnabledCommand(id: 'el-fx', index: 0, enabled: true).apply(off);
      expect(_effect(on, 0).containsKey('enabled'), isFalse);
    });
  });

  group('SetEffectParamCommand', () {
    test('writes a literal, which is the stopwatch turning off', () {
      final document = EditorDocument.fromJson(
        _deck(
          effects: [
            {
              'kind': 'vignette',
              'amount': {
                'values': [0, 0.9],
                'positions': ['0f', '120f'],
              },
            },
          ],
        ),
      );
      const command = SetEffectParamCommand(id: 'el-fx', index: 0, param: 'amount', value: 0.45);
      final next = command.apply(document);

      expect(_effect(next, 0)['amount'], 0.45);
    });

    test('writes a keyframed value, which is the stopwatch turning on', () {
      final document = EditorDocument.fromJson(
        _deck(
          effects: [
            {'kind': 'grain', 'amount': 0.3},
          ],
        ),
      );
      const command = SetEffectParamCommand(
        id: 'el-fx',
        index: 0,
        param: 'amount',
        value: {
          'values': [0.3, 0.3],
          'positions': ['0f', '120f'],
        },
      );
      final next = command.apply(document);

      expect((_effect(next, 0)['amount']! as Map)['values'], [0.3, 0.3]);
    });

    test('scrubs coalesce into one undo step', () {
      final history = DocumentHistory(
        EditorDocument.fromJson(
          _deck(
            effects: [
              {'kind': 'grain', 'amount': 0.3},
            ],
          ),
        ),
      );
      final before = history.document.toJson();

      history
        ..dispatch(
          const SetEffectParamCommand(
            id: 'el-fx',
            index: 0,
            param: 'amount',
            value: 0.5,
            mergeGroup: 'scrub-1',
          ),
        )
        ..dispatch(
          const SetEffectParamCommand(
            id: 'el-fx',
            index: 0,
            param: 'amount',
            value: 0.7,
            mergeGroup: 'scrub-1',
          ),
        )
        ..undo();

      expect(history.document.toJson(), before);
    });

    test('a null value clears the parameter back to its default', () {
      final document = EditorDocument.fromJson(
        _deck(
          effects: [
            {'kind': 'grain', 'amount': 0.3},
          ],
        ),
      );
      const command = SetEffectParamCommand(id: 'el-fx', index: 0, param: 'amount', value: null);
      final next = command.apply(document);

      expect(_effect(next, 0).containsKey('amount'), isFalse);
    });
  });
}
