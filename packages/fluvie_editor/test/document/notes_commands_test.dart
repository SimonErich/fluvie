import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({bool stepped = true}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    <String, Object?>{
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
      ],
      if (stepped)
        'steps': [
          {
            'elements': ['el-b'],
          },
        ],
    },
  ],
};

void main() {
  group('SetSceneNotesCommand', () {
    test('writes the notes object onto the scene and undoes back', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetSceneNotesCommand(
            index: 0,
            notes: {
              'text': 'Open with the story.',
              'highlights': ['one', 'two'],
            },
          ),
        );
      expect(history.document.sceneJson(0)['notes'], {
        'text': 'Open with the story.',
        'highlights': ['one', 'two'],
      });
      history.undo();
      expect(history.document.sceneJson(0).containsKey('notes'), isFalse);
    });

    test('canonicalizes: empty text and empty highlights drop their keys', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetSceneNotesCommand(
            index: 0,
            notes: {
              'text': '',
              'highlights': <String>['keep'],
            },
          ),
        );
      expect(history.document.sceneJson(0)['notes'], {
        'highlights': ['keep'],
      });
      history.dispatch(
        const SetSceneNotesCommand(
          index: 0,
          notes: {'text': 'say this', 'highlights': <String>[]},
        ),
      );
      expect(history.document.sceneJson(0)['notes'], {'text': 'say this'});
    });

    test('a content-free notes object removes the key — no empty residue', () {
      final start = _deck();
      (start['scenes']! as List)[0] = {
        ...((start['scenes']! as List)[0]! as Map<String, Object?>),
        'notes': {'text': 'old'},
      };
      final history = DocumentHistory(EditorDocument.fromJson(start))
        ..dispatch(
          const SetSceneNotesCommand(
            index: 0,
            notes: {'text': '', 'highlights': <String>[]},
          ),
        );
      expect(history.document.sceneJson(0).containsKey('notes'), isFalse);
      history.undo();
      expect(history.document.sceneJson(0)['notes'], {'text': 'old'});
    });

    test('null notes removes the key', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const SetSceneNotesCommand(index: 0, notes: {'text': 'x'}))
        ..dispatch(const SetSceneNotesCommand(index: 0, notes: null));
      expect(history.document.sceneJson(0).containsKey('notes'), isFalse);
    });

    test('round-trips: toJson then fromJson is identical', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetSceneNotesCommand(
            index: 0,
            notes: {
              'text': 'the story',
              'highlights': ['a'],
            },
          ),
        );
      final json = history.document.toJson();
      final reloaded = EditorDocument.fromJson(json);
      expect(jsonEncode(reloaded.toJson()), jsonEncode(json));
    });

    test('moves the render digest — notes are presentation content', () {
      final before = EditorDocument.fromJson(_deck());
      const command = SetSceneNotesCommand(index: 0, notes: {'text': 'say'});
      expect(command.apply(before).renderDigest, isNot(before.renderDigest));
    });

    test('labels itself for the undo menu and touches no elements', () {
      const command = SetSceneNotesCommand(index: 0, notes: {'text': 'x'});
      expect(command.label, 'Edit speaker notes');
      expect(command.affectedIds, isEmpty);
    });
  });

  group('SetStepNotesCommand', () {
    test('writes the notes onto the listed step and undoes back', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetStepNotesCommand(
            index: 0,
            step: 0,
            notes: {
              'text': 'Land the punchline.',
              'highlights': ['now'],
            },
          ),
        );
      expect(history.document.sceneJson(0)['steps'], [
        {
          'elements': ['el-b'],
          'notes': {
            'text': 'Land the punchline.',
            'highlights': ['now'],
          },
        },
      ]);
      history.undo();
      expect(history.document.sceneJson(0)['steps'], [
        {
          'elements': ['el-b'],
        },
      ]);
    });

    test('clearing all content removes the step notes key, keeping elements', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const SetStepNotesCommand(index: 0, step: 0, notes: {'text': 'said'}))
        ..dispatch(
          const SetStepNotesCommand(index: 0, step: 0, notes: {'text': '', 'highlights': []}),
        );
      expect(history.document.sceneJson(0)['steps'], [
        {
          'elements': ['el-b'],
        },
      ]);
    });

    test('edits only its step and moves the render digest', () {
      final start = _deck();
      final scene = (start['scenes']! as List)[0]! as Map<String, Object?>;
      scene['steps'] = [
        {
          'elements': ['el-a'],
          'notes': {'text': 'first'},
        },
        {
          'elements': ['el-b'],
        },
      ];
      final before = EditorDocument.fromJson(start);
      const command = SetStepNotesCommand(index: 0, step: 1, notes: {'text': 'second'});
      final after = command.apply(before);
      expect(after.sceneJson(0)['steps'], [
        {
          'elements': ['el-a'],
          'notes': {'text': 'first'},
        },
        {
          'elements': ['el-b'],
          'notes': {'text': 'second'},
        },
      ]);
      expect(after.renderDigest, isNot(before.renderDigest));
      expect(command.label, 'Edit step notes');
      expect(command.affectedIds, isEmpty);
    });

    test('round-trips through toJson and fromJson', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetStepNotesCommand(
            index: 0,
            step: 0,
            notes: {
              'highlights': ['bullet only'],
            },
          ),
        );
      final json = history.document.toJson();
      expect(jsonEncode(EditorDocument.fromJson(json).toJson()), jsonEncode(json));
    });
  });
}
