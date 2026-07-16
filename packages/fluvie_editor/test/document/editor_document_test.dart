import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show FluvieSpecError;
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
          'id': 'el-title',
          'type': 'Text',
          'text': 'one',
          'transform': {'x': 0.5, 'y': 0.2},
        },
        {'type': 'Text', 'text': 'two'},
      ],
    },
    {
      'duration': '30f',
      'children': [
        {'type': 'Box', 'color': '#6C5CE7'},
      ],
    },
  ],
};

void main() {
  group('loading', () {
    test('parses and mints ids for elements without one', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.elementIdsInScene(0), ['el-title', 'el-1']);
      expect(doc.elementIdsInScene(1), ['el-2']);
    });

    test('minted ids never collide with existing ones', () {
      final json = _deck();
      final scene = (json['scenes']! as List).first as Map<String, Object?>;
      ((scene['children']! as List).last as Map<String, Object?>)['id'] = 'el-1';
      final doc = EditorDocument.fromJson(json);
      final ids = [...doc.elementIdsInScene(0), ...doc.elementIdsInScene(1)];
      expect(ids.toSet(), hasLength(3));
    });

    test('a malformed document throws the spec error', () {
      expect(
        () => EditorDocument.fromJson(const {'scenes': <Object?>[]}),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('toJson carries the minted ids (saving is identity from here on)', () {
      final doc = EditorDocument.fromJson(_deck());
      final reloaded = EditorDocument.fromJson(doc.toJson());
      expect(reloaded.toJson(), doc.toJson());
    });
  });

  group('lookups', () {
    test('elementJson returns the element by id; sceneOfElement locates it', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.elementJson('el-title')?['text'], 'one');
      expect(doc.sceneOfElement('el-title'), 0);
      expect(doc.sceneOfElement('el-2'), 1);
      expect(doc.elementJson('missing'), isNull);
      expect(doc.sceneOfElement('missing'), isNull);
    });

    test('sceneCount and sceneJson expose the deck shape', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.sceneCount, 2);
      expect(doc.sceneJson(1)['duration'], '30f');
    });
  });

  group('element mutations', () {
    test('replaceElement swaps content and leaves the original untouched', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.replaceElement('el-title', {
        'id': 'el-title',
        'type': 'Text',
        'text': 'renamed',
      });
      expect(next.elementJson('el-title')?['text'], 'renamed');
      expect(doc.elementJson('el-title')?['text'], 'one');
    });

    test('replaceElement keeps the id even when the patch drops it', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.replaceElement('el-title', {'type': 'Text', 'text': 'renamed'});
      expect(next.elementJson('el-title'), isNotNull);
    });

    test('setTransform writes the transform key', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.setTransform('el-1', {'x': 0.7, 'y': 0.7, 'w': 0.2, 'h': 0.2});
      expect(next.elementJson('el-1')?['transform'], {'x': 0.7, 'y': 0.7, 'w': 0.2, 'h': 0.2});
      expect(doc.elementJson('el-1')?.containsKey('transform'), isFalse);
    });

    test('insertElement mints an id when none is given and appends', () {
      final doc = EditorDocument.fromJson(_deck());
      final (next, id) = doc.insertElement(1, {'type': 'Text', 'text': 'new'});
      expect(next.elementIdsInScene(1), ['el-2', id]);
      expect(next.elementJson(id)?['text'], 'new');
      expect(doc.sceneCount, next.sceneCount);
    });

    test('insertElement respects an explicit position', () {
      final doc = EditorDocument.fromJson(_deck());
      final (next, id) = doc.insertElement(0, {'type': 'Box'}, at: 0);
      expect(next.elementIdsInScene(0).first, id);
    });

    test('removeElement drops it; unknown ids throw', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.removeElement('el-1');
      expect(next.elementIdsInScene(0), ['el-title']);
      expect(() => doc.removeElement('missing'), throwsArgumentError);
    });

    test('reorderElement moves within its scene (z-order)', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.reorderElement('el-title', to: 1);
      expect(next.elementIdsInScene(0), ['el-1', 'el-title']);
    });
  });

  group('scene mutations', () {
    test('addScene appends or inserts', () {
      final doc = EditorDocument.fromJson(_deck());
      final appended = doc.addScene({'duration': '10f', 'children': <Object?>[]});
      expect(appended.sceneCount, 3);
      final inserted = doc.addScene({'duration': '10f', 'children': <Object?>[]}, at: 0);
      expect(inserted.sceneJson(0)['duration'], '10f');
    });

    test('removeScene drops it and its element ids', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.removeScene(0);
      expect(next.sceneCount, 1);
      expect(next.elementJson('el-title'), isNull);
    });

    test('the last scene cannot be removed (a deck is never empty)', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(() => doc.removeScene(0).removeScene(0), throwsStateError);
    });

    test('reorderScene moves a slide', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.reorderScene(0, 1);
      expect(next.sceneJson(0)['duration'], '30f');
      expect(next.elementIdsInScene(1), ['el-title', 'el-1']);
    });
  });

  group('editor metadata', () {
    test('element meta reads and writes through the editor block', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.elementMeta('el-title'), isEmpty);
      final next = doc.setElementMeta('el-title', {'name': 'Headline', 'locked': true});
      expect(next.elementMeta('el-title'), {'name': 'Headline', 'locked': true});
      expect(next.toJson()['editor'], isNotNull);
      expect(doc.toJson()['editor'], isNull);
    });

    test('metadata never moves the render digest', () {
      final doc = EditorDocument.fromJson(_deck());
      final annotated = doc.setElementMeta('el-title', {'name': 'Headline'});
      expect(annotated.renderDigest, doc.renderDigest);
      expect(annotated.documentDigest, isNot(doc.documentDigest));
    });

    test('content changes move both digests', () {
      final doc = EditorDocument.fromJson(_deck());
      final next = doc.setTransform('el-title', {'x': 0.1, 'y': 0.1});
      expect(next.renderDigest, isNot(doc.renderDigest));
      expect(next.documentDigest, isNot(doc.documentDigest));
    });
  });

  group('spec access', () {
    test('spec builds the same Video shape the JSON describes', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.spec.scenes, hasLength(2));
      expect(doc.spec.build().scenes, hasLength(2));
    });
  });
}
