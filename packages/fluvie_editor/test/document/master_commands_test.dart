import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'theme': {
    'palette': {'accent': '#111111'},
  },
  'masters': {
    'base': {
      'children': [
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2},
        },
      ],
    },
  },
  'scenes': [
    {'duration': '60f', 'master': 'base', 'children': <Object?>[]},
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

void main() {
  group('SetMasterCommand', () {
    test('writes the master and undoes as one step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final master = {
        'children': [
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.2},
          },
        ],
      };
      history.dispatch(SetMasterCommand(name: 'base', master: master));
      expect(history.document.masterJson('base'), master);
      history.undo();
      expect(
        history.document.masterJson('base')!['children'],
        isNot(master['children']),
      );
    });

    test('a merge group coalesces a stream into one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      Map<String, Object?> masterAt(double y) => {
        'children': [
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': y, 'w': 0.8, 'h': 0.2},
          },
        ],
      };
      history
        ..dispatch(SetMasterCommand(name: 'base', master: masterAt(0.4), mergeGroup: 'drag'))
        ..dispatch(SetMasterCommand(name: 'base', master: masterAt(0.6), mergeGroup: 'drag'))
        ..undo();
      expect(
        history.document.masterJson('base'),
        EditorDocument.fromJson(_deck()).masterJson('base'),
      );
      expect(history.canUndo, isFalse);
    });

    test('the label carries the verb', () {
      expect(const SetMasterCommand(name: 'base', master: {}).label, 'Edit master');
      expect(const SetMasterCommand(name: 'base', master: {}, verb: 'Add').label, 'Add master');
    });
  });

  group('ApplyMasterCommand and DetachMasterCommand', () {
    test('apply adopts, detach releases, both undo', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const ApplyMasterCommand(slide: 1, name: 'base'));
      expect(history.document.sceneMasterName(1), 'base');
      history.dispatch(const DetachMasterCommand(slide: 1));
      expect(history.document.sceneMasterName(1), isNull);
      history
        ..undo()
        ..undo();
      expect(history.document.sceneMasterName(1), isNull);
      expect(const ApplyMasterCommand(slide: 1, name: 'base').label, 'Apply master');
      expect(const DetachMasterCommand(slide: 1).label, 'Detach master');
    });
  });

  group('FillSlotCommand', () {
    test('fills the slot with the carried id and undoes', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const FillSlotCommand(
            slide: 0,
            slot: 'title',
            id: 'el-1',
            element: {'type': 'Text', 'text': 'Hello'},
          ),
        );
      expect(history.document.fillSlotOf('el-1'), 'title');
      expect(history.document.elementJson('el-1')!['text'], 'Hello');
      history.undo();
      expect(history.document.elementJson('el-1'), isNull);
      expect(
        const FillSlotCommand(slide: 0, slot: 'title', id: 'el-1', element: {}).affectedIds,
        {'el-1'},
      );
    });
  });

  group('InsertTemplateSlideCommand', () {
    const templateTheme = {
      'palette': {'accent': '#FF0000', 'extra': '#00FF00'},
      'spacing': {'s': 8},
    };
    const templateMasters = {
      'base': {
        'children': [
          {'type': 'Placeholder', 'slot': 'other'},
        ],
      },
      'closing': {
        'children': [
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.6, 'h': 0.3},
          },
        ],
      },
    };

    test('inserts the scene and merges tokens and masters additively, as one step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const InsertTemplateSlideCommand(
            scene: {
              'duration': '60f',
              'master': 'closing',
              'fills': {
                'title': {'id': 'el-9', 'type': 'Text', 'text': 'From template'},
              },
              'children': <Object?>[],
            },
            at: 1,
            theme: templateTheme,
            masters: templateMasters,
          ),
        );
      final document = history.document;
      expect(document.sceneCount, 3);
      expect(document.sceneMasterName(1), 'closing');
      // The deck's own token survives; the missing ones arrive.
      final theme = document.themeJson!;
      expect((theme['palette']! as Map)['accent'], '#111111');
      expect((theme['palette']! as Map)['extra'], '#00FF00');
      expect((theme['spacing']! as Map)['s'], 8);
      // The deck's master wins a name collision; the new one arrives.
      expect(
        ((document.masterJson('base')!['children']! as List).single as Map)['slot'],
        'title',
      );
      expect(document.masterNames, contains('closing'));
      // One undo step reverts the scene and the merge together.
      history.undo();
      expect(history.document.sceneCount, 2);
      expect(history.document.masterNames, ['base']);
      expect((history.document.themeJson!['palette']! as Map).containsKey('extra'), isFalse);
      expect(history.canUndo, isFalse);
    });

    test('a template without theme or masters just inserts', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const InsertTemplateSlideCommand(
            scene: {'duration': '60f', 'children': <Object?>[]},
          ),
        );
      expect(history.document.sceneCount, 3);
      expect(history.document.themeJson, EditorDocument.fromJson(_deck()).themeJson);
    });

    test('a template theme lands whole on a themeless deck', () {
      final deck = _deck()..remove('theme');
      final history = DocumentHistory(EditorDocument.fromJson(deck))
        ..dispatch(
          const InsertTemplateSlideCommand(
            scene: {'duration': '60f', 'children': <Object?>[]},
            theme: templateTheme,
          ),
        );
      expect(history.document.themeJson, templateTheme);
    });
  });

  group('preparedTemplateScene', () {
    test('mints ids for children, nested group children, and fills', () {
      final document = EditorDocument.fromJson(_deck());
      final scene = preparedTemplateScene(document, {
        'duration': '60f',
        'master': 'base',
        'fills': {
          'title': {'type': 'Text', 'text': 'T'},
        },
        'children': [
          {
            'type': 'Group',
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
            'children': [
              {'type': 'Box', 'color': '#123456'},
            ],
          },
        ],
      });
      final group = (scene['children']! as List).first! as Map<String, Object?>;
      final nested = (group['children']! as List).first! as Map<String, Object?>;
      final fill = ((scene['fills']! as Map)['title']!) as Map<String, Object?>;
      final ids = {group['id'], nested['id'], fill['id']};
      expect(ids, hasLength(3));
      expect(ids, everyElement(isA<String>()));
    });
  });
}
