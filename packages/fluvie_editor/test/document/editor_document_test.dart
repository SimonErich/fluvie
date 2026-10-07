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

    test('scene meta reads and writes through the editor block', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.sceneMeta(0), isEmpty);
      final next = doc.setSceneMeta(0, {
        'guides': [
          {'axis': 'vertical', 'pos': 0.5},
        ],
      });
      expect(next.sceneMeta(0), {
        'guides': [
          {'axis': 'vertical', 'pos': 0.5},
        ],
      });
      expect(next.sceneMeta(1), isEmpty);
      expect(doc.sceneMeta(0), isEmpty, reason: 'the original stays untouched');
      // A second write merges over the first.
      final renamed = next.setSceneMeta(0, {'note': 'intro'});
      expect(renamed.sceneMeta(0).keys, containsAll(['guides', 'note']));
    });

    test('guides never move the render digest', () {
      final doc = EditorDocument.fromJson(_deck());
      final guided = doc.setSceneMeta(0, {
        'guides': [
          {'axis': 'horizontal', 'pos': 0.25},
        ],
      });
      expect(guided.renderDigest, doc.renderDigest);
      expect(guided.documentDigest, isNot(doc.documentDigest));
    });

    test('scene meta follows its slide through reorder, insert, and removal', () {
      final doc = EditorDocument.fromJson(
        _deck(),
      ).setSceneMeta(0, {'note': 'first'}).setSceneMeta(1, {'note': 'second'});

      final reordered = doc.reorderScene(0, 1);
      expect(reordered.sceneMeta(0), {'note': 'second'});
      expect(reordered.sceneMeta(1), {'note': 'first'});

      final inserted = doc.addScene({'duration': '10f'}, at: 0);
      expect(inserted.sceneMeta(0), isEmpty);
      expect(inserted.sceneMeta(1), {'note': 'first'});
      expect(inserted.sceneMeta(2), {'note': 'second'});

      final removed = doc.removeScene(0);
      expect(removed.sceneMeta(0), {'note': 'second'});
    });

    test('setSceneMeta rejects an index the deck does not have', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(() => doc.setSceneMeta(9, {'note': 'nope'}), throwsRangeError);
    });

    test('the remap tolerates hand-edited editor blocks', () {
      // A non-index key is dropped rather than guessed at; a block without
      // per-slide metadata passes through untouched.
      final json = _deck();
      json['editor'] = {
        'editorSchema': 1,
        'scenes': {
          'not-a-number': {'note': 'junk'},
          '0': {'note': 'first'},
        },
      };
      final reordered = EditorDocument.fromJson(json).reorderScene(0, 1);
      expect(reordered.sceneMeta(1), {'note': 'first'});
      final editor = reordered.toJson()['editor']! as Map<String, Object?>;
      expect((editor['scenes']! as Map<String, Object?>).keys, ['1']);

      // Element metadata alone (no scenes map) survives a reorder.
      final elementOnly = EditorDocument.fromJson(
        _deck(),
      ).setElementMeta('el-title', {'name': 'Headline'}).reorderScene(0, 1);
      expect(elementOnly.elementMeta('el-title'), {'name': 'Headline'});
    });
  });

  group('spec access', () {
    test('spec builds the same Video shape the JSON describes', () {
      final doc = EditorDocument.fromJson(_deck());
      expect(doc.spec.scenes, hasLength(2));
      expect(doc.spec.build().scenes, hasLength(2));
    });
  });
  patchSuite();
}

// Scene and video patches back the inspector's background and deck fields.
void patchSuite() {
  test('updateScene merges keys and null removes them', () {
    final document = EditorDocument.fromJson(_deck());
    final withBackground = document.updateScene(0, {
      'background': {'kind': 'color', 'color': '#FF0000'},
    });
    expect(
      withBackground.sceneJson(0)['background'],
      {'kind': 'color', 'color': '#FF0000'},
    );
    // The original stayed untouched, and null clears.
    expect(document.sceneJson(0).containsKey('background'), isFalse);
    final cleared = withBackground.updateScene(0, {'background': null});
    expect(cleared.sceneJson(0).containsKey('background'), isFalse);
  });

  test('updateVideo patches deck-level keys but never scenes or editor', () {
    final document = EditorDocument.fromJson(_deck());
    final resized = document.updateVideo({
      'size': {'width': 640, 'height': 360},
    });
    expect(resized.toJson()['size'], {'width': 640, 'height': 360});
    expect(resized.sceneCount, document.sceneCount);
    expect(() => document.updateVideo({'scenes': <Object?>[]}), throwsArgumentError);
    expect(() => document.updateVideo({'editor': <String, Object?>{}}), throwsArgumentError);
  });
  duplicateSuite();
}

// Duplicating a slide must re-mint every element id.
void duplicateSuite() {
  test('duplicatedScene copies content with fresh ids', () {
    final document = EditorDocument.fromJson(_deck());
    final copy = document.duplicatedScene(0);
    final original = document.sceneJson(0);
    final copiedChildren = (copy['children']! as List).cast<Map<String, Object?>>();
    final originalChildren = (original['children']! as List).cast<Map<String, Object?>>();
    expect(copiedChildren, hasLength(originalChildren.length));
    final existing = {
      for (var s = 0; s < document.sceneCount; s++) ...document.elementIdsInScene(s),
    };
    for (var i = 0; i < copiedChildren.length; i++) {
      expect(copiedChildren[i]['id'], isNot(originalChildren[i]['id']));
      expect(existing, isNot(contains(copiedChildren[i]['id'])));
      expect(copiedChildren[i]['type'], originalChildren[i]['type']);
    }
    // The copies are distinct from each other too.
    expect(copiedChildren.map((c) => c['id']).toSet(), hasLength(copiedChildren.length));
    // Adding it round-trips through the command layer cleanly.
    final grown = document.addScene(copy);
    expect(grown.sceneCount, document.sceneCount + 1);
    expect(
      grown.elementIdsInScene(grown.sceneCount - 1),
      copiedChildren.map((c) => c['id']).toList(),
    );
  });
}
