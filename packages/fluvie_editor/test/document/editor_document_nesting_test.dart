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
          'id': 'el-back',
          'type': 'Box',
          'color': '#101018',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
        },
        {
          'id': 'el-group',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {
              'id': 'el-a',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.25, 'y': 0.5, 'w': 0.5, 'h': 1.0},
            },
            {'type': 'Text', 'text': 'inside'},
          ],
        },
      ],
    },
  ],
};

void main() {
  group('nested addressing', () {
    test('loading mints ids for group children too', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.childIdsOfGroup('el-group'), ['el-a', 'el-1']);
    });

    test('nextId counts nested ids so minting never collides', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.nextId(), 'el-2');
    });

    test('elementJson and sceneOfElement find group children', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.elementJson('el-a')?['color'], '#6C5CE7');
      expect(doc.sceneOfElement('el-a'), 0);
    });

    test('parentGroupOf names the holding group, null at top level', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.parentGroupOf('el-a'), 'el-group');
      expect(doc.parentGroupOf('el-back'), isNull);
      expect(doc.parentGroupOf('missing'), isNull);
    });

    test('childIdsOfGroup is empty for non-groups and unknown ids', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.childIdsOfGroup('el-back'), isEmpty);
      expect(doc.childIdsOfGroup('missing'), isEmpty);
    });

    test('elementIdsInScene stays top-level (a group is one z-slot)', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.elementIdsInScene(0), ['el-back', 'el-group']);
    });

    test('setTransform reaches a group child', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.setTransform('el-a', {'x': 0.75, 'y': 0.5, 'w': 0.5, 'h': 1.0});
      expect(next.elementJson('el-a')?['transform'], {'x': 0.75, 'y': 0.5, 'w': 0.5, 'h': 1.0});
      expect(next.parentGroupOf('el-a'), 'el-group');
    });

    test('replaceElement reaches a group child and keeps its id', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.replaceElement('el-a', {'type': 'Box', 'color': '#FFFFFF'});
      expect(next.elementJson('el-a')?['color'], '#FFFFFF');
      expect(next.childIdsOfGroup('el-group').first, 'el-a');
    });

    test('removeElement drops a group child from the group', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.removeElement('el-a');
      expect(next.elementJson('el-a'), isNull);
      expect(next.childIdsOfGroup('el-group'), hasLength(1));
    });

    test('reorderElement moves within the group children list', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.reorderElement('el-a', to: 1);
      expect(next.childIdsOfGroup('el-group'), ['el-1', 'el-a']);
      expect(next.elementIdsInScene(0), ['el-back', 'el-group']);
    });

    test('duplicatedScene re-mints nested ids uniquely', () {
      final doc = EditorDocument.fromJson(_deck());
      final copy = doc.duplicatedScene(0);
      final next = doc.addScene(copy);
      final all = <String>{
        for (var s = 0; s < next.sceneCount; s++) ...next.elementIdsInScene(s),
        ...next.childIdsOfGroup('el-group'),
      };
      final copiedGroup = next.elementIdsInScene(1)[1];
      final copiedChildren = next.childIdsOfGroup(copiedGroup);
      expect(copiedChildren, hasLength(2));
      expect(all.intersection(copiedChildren.toSet()), isEmpty);
      expect(
        {...all, ...copiedChildren},
        hasLength(all.length + copiedChildren.length),
      );
    });
  });

  group('hidden-meta migration', () {
    test('editor-block hidden becomes the spec visible flag on load', () {
      final json = _deck();
      json['editor'] = {
        'editorSchema': 1,
        'elements': {
          'el-a': {'hidden': true, 'name': 'Accent'},
        },
      };
      final doc = EditorDocument.fromJson(json);
      expect(doc.elementJson('el-a')?['visible'], false);
      expect(doc.elementMeta('el-a').containsKey('hidden'), isFalse);
      expect(doc.elementMeta('el-a')['name'], 'Accent');
    });

    test('a false hidden flag is dropped without touching visible', () {
      final json = _deck();
      json['editor'] = {
        'editorSchema': 1,
        'elements': {
          'el-back': {'hidden': false},
        },
      };
      final doc = EditorDocument.fromJson(json);
      expect(doc.elementJson('el-back')?.containsKey('visible'), isFalse);
      expect(doc.elementMeta('el-back').containsKey('hidden'), isFalse);
    });

    test('migration matches an explicitly authored visible flag digest', () {
      final migrated = _deck();
      migrated['editor'] = {
        'editorSchema': 1,
        'elements': {
          'el-back': {'hidden': true},
        },
      };
      final authored = _deck();
      final scene = (authored['scenes']! as List).first as Map<String, Object?>;
      ((scene['children']! as List).first as Map<String, Object?>)['visible'] = false;
      expect(
        EditorDocument.fromJson(migrated).renderDigest,
        EditorDocument.fromJson(authored).renderDigest,
      );
    });
  });

  group('setElementVisible', () {
    test('false writes the flag, true removes it (the canonical elision)', () {
      final doc = EditorDocument.fromJson(_deck());
      final hidden = doc.setElementVisible('el-back', visible: false);
      expect(hidden.elementJson('el-back')?['visible'], false);
      final shown = hidden.setElementVisible('el-back', visible: true);
      expect(shown.elementJson('el-back')?.containsKey('visible'), isFalse);
    });

    test('visibility moves the render digest (hiding IS a render change)', () {
      final doc = EditorDocument.fromJson(_deck());
      final hidden = doc.setElementVisible('el-back', visible: false);
      expect(hidden.renderDigest, isNot(doc.renderDigest));
    });

    test('reaches a group child', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.setElementVisible('el-a', visible: false);
      expect(next.elementJson('el-a')?['visible'], false);
    });
  });
}
