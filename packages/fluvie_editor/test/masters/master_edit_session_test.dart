import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'theme': {
    'palette': {'accent': '#6C5CE7'},
  },
  'masters': {
    'base': {
      'background': {'kind': 'color', 'color': '#101018'},
      'children': [
        {
          'type': 'Box',
          'color': '#26FFFFFF',
          'transform': {'x': 0.5, 'y': 0.9, 'w': 1.0, 'h': 0.08},
        },
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2},
          'style': {'fontSize': 40},
        },
        {'type': 'Placeholder', 'slot': 'media'},
      ],
    },
  },
  'scenes': [
    {'duration': '60f', 'master': 'base', 'children': <Object?>[]},
    {
      'duration': '60f',
      'master': 'base',
      'fills': {
        'title': {'id': 'el-t', 'type': 'Text', 'text': 'Two'},
      },
      'children': <Object?>[],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

MasterEditSession _session() => MasterEditSession(EditorDocument.fromJson(_deck()), 'base');

void main() {
  group('the synthetic view', () {
    test('is a single-scene document shaped like the master', () {
      final session = _session();
      final view = session.view;
      expect(view.sceneCount, 1);
      expect(view.sceneJson(0)['background'], {'kind': 'color', 'color': '#101018'});
      expect(view.toJson()['theme'], {
        'palette': {'accent': '#6C5CE7'},
      });
      expect(view.elementIdsInScene(0), ['m-0', 's-1', 's-2']);
    });

    test('chrome children carry transient ids, placeholders become labeled boxes', () {
      final view = _session().view;
      expect(view.elementJson('m-0')!['type'], 'Box');
      final slot = view.elementJson('s-1')!;
      expect(slot['type'], 'Group');
      expect(slot['transform'], {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2});
      final labels = [
        for (final id in view.childIdsOfGroup('s-1')) view.elementJson(id)!['text'],
      ];
      expect(labels, contains('title'));
    });

    test('a placeholder without a transform gets the default slot box', () {
      final view = _session().view;
      final transform = view.elementJson('s-2')!['transform']! as Map<String, Object?>;
      expect(transform['w'], isNotNull);
      expect(transform['h'], isNotNull);
    });

    test('an unknown master name fails loudly', () {
      expect(
        () => MasterEditSession(EditorDocument.fromJson(_deck()), 'nope'),
        throwsArgumentError,
      );
    });
  });

  group('translation', () {
    test('a chrome transform edit writes the master child', () {
      final session = _session();
      final translated = session.translate(
        const SetTransformCommand(
          id: 'm-0',
          transform: {'x': 0.5, 'y': 0.1, 'w': 1.0, 'h': 0.08},
        ),
      );
      expect(translated, isA<SetMasterCommand>());
      final master = (translated! as SetMasterCommand).master!;
      final chrome = (master['children']! as List).first! as Map<String, Object?>;
      expect(chrome['transform'], {'x': 0.5, 'y': 0.1, 'w': 1.0, 'h': 0.08});
      expect(chrome.containsKey('id'), isFalse);
      expect((translated as SetMasterCommand).mergeGroup, 'transform:m-0');
    });

    test('a placeholder move writes the placeholder transform, keeping slot and style', () {
      final session = _session();
      final translated = session.translate(
        const SetTransformsCommand(
          transforms: {
            's-1': {'x': 0.5, 'y': 0.7, 'w': 0.8, 'h': 0.2},
          },
          mergeGroup: 'nudge',
        ),
      );
      final master = (translated! as SetMasterCommand).master!;
      final slot = (master['children']! as List)[1]! as Map<String, Object?>;
      expect(slot['type'], 'Placeholder');
      expect(slot['slot'], 'title');
      expect(slot['style'], {'fontSize': 40});
      expect(slot['transform'], {'x': 0.5, 'y': 0.7, 'w': 0.8, 'h': 0.2});
    });

    test('an untouched transformless placeholder stays transformless', () {
      final session = _session();
      final translated = session.translate(
        const SetTransformCommand(id: 'm-0', transform: {'x': 0.2, 'y': 0.2}),
      );
      final master = (translated! as SetMasterCommand).master!;
      final media = (master['children']! as List)[2]! as Map<String, Object?>;
      expect(media.containsKey('transform'), isFalse);
    });

    test('deleting a placeholder is refused', () {
      final session = _session();
      expect(session.translate(const RemoveElementCommand(id: 's-1')), isNull);
      expect(
        session.translate(
          const RemoveElementsCommand(ids: ['m-0', 's-1']),
        ),
        isNull,
      );
    });

    test('deleting chrome drops the master child', () {
      final session = _session();
      final translated = session.translate(const RemoveElementCommand(id: 'm-0'));
      final master = (translated! as SetMasterCommand).master!;
      final types = [
        for (final child in master['children']! as List) (child! as Map)['type'],
      ];
      expect(types, ['Placeholder', 'Placeholder']);
    });

    test('inserting an element adds identity-free chrome', () {
      final session = _session();
      final translated = session.translate(
        const InsertElementCommand(
          scene: 0,
          id: 'el-9',
          element: {
            'type': 'Text',
            'text': 'Footer',
            'anchor': 'x',
            'transform': {'x': 0.5, 'y': 0.95},
          },
        ),
      );
      final master = (translated! as SetMasterCommand).master!;
      final added = (master['children']! as List).last! as Map<String, Object?>;
      expect(added['type'], 'Text');
      expect(added.containsKey('id'), isFalse);
      expect(added.containsKey('anchor'), isFalse);
    });

    test('reordering children reorders the master', () {
      final session = _session();
      final translated = session.translate(const ReorderElementCommand(id: 'm-0', to: 2));
      final master = (translated! as SetMasterCommand).master!;
      final types = [
        for (final child in master['children']! as List) (child! as Map)['type'],
      ];
      expect(types, ['Placeholder', 'Placeholder', 'Box']);
    });

    test('a background edit becomes the master background', () {
      final session = _session();
      final translated = session.translate(
        const UpdateSceneCommand(
          index: 0,
          patch: {
            'background': {'kind': 'color', 'color': '#FF0000'},
          },
        ),
      );
      final master = (translated! as SetMasterCommand).master!;
      expect(master['background'], {'kind': 'color', 'color': '#FF0000'});
    });

    test('commands that change nothing of the master translate to null', () {
      final session = _session();
      expect(
        session.translate(const UpdateSceneCommand(index: 0, patch: {'duration': '90f'})),
        isNull,
      );
      expect(
        session.translate(const AddSceneCommand(scene: {'duration': '60f'})),
        isNull,
      );
    });

    test('commands that throw against the view translate to null', () {
      final session = _session();
      expect(session.translate(const RemoveSceneCommand(index: 0)), isNull);
      expect(session.translate(const RemoveElementCommand(id: 'nope')), isNull);
    });
  });

  group('propagation', () {
    test('one master edit re-derives every adopting slide', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()));
      final deriver = SlideDeriver();
      final beforeZero = deriver.derive(history.document, 0);
      final beforeOne = deriver.derive(history.document, 1);
      final beforeFree = deriver.derive(history.document, 2);
      final session = MasterEditSession(history.document, 'base');
      history.dispatch(
        session.translate(
          const SetTransformCommand(
            id: 'm-0',
            transform: {'x': 0.5, 'y': 0.1, 'w': 1.0, 'h': 0.08},
          ),
        )!,
      );
      expect(deriver.derive(history.document, 0), isNot(same(beforeZero)));
      expect(deriver.derive(history.document, 1), isNot(same(beforeOne)));
      // The deriver keys on the whole masters block (7.2's coarse key), so
      // the freeform slide re-derives too — but to identical output.
      expect(deriver.derive(history.document, 2), isNot(same(beforeFree)));
      history.undo();
      expect(deriver.derive(history.document, 0), same(beforeZero));
    });
  });
}
