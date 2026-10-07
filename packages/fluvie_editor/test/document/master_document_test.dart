import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'masters': {
    'title': {
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
    'closing': {
      'children': [
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.6, 'h': 0.3},
        },
      ],
    },
  },
  'scenes': [
    {
      'duration': '60f',
      'master': 'title',
      'fills': {
        'title': {'id': 'el-t', 'type': 'Text', 'text': 'Filled'},
      },
      'children': [
        {
          'id': 'el-top',
          'type': 'Box',
          'color': '#0984E3',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

void main() {
  group('master queries', () {
    test('masterNames lists the masters in document order', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.masterNames, ['title', 'closing']);
      expect(EditorDocument.fromJson(_blankDeck()).masterNames, isEmpty);
    });

    test('masterJson returns a copy, null for unknown names', () {
      final document = EditorDocument.fromJson(_deck());
      final master = document.masterJson('title')!;
      expect(master['children']! as List, hasLength(3));
      master['children'] = <Object?>[];
      expect(document.masterJson('title')!['children']! as List, hasLength(3));
      expect(document.masterJson('nope'), isNull);
    });

    test('sceneMasterName reads the adoption', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.sceneMasterName(0), 'title');
      expect(document.sceneMasterName(1), isNull);
    });

    test('masterSlots joins placeholders with their fills in master order', () {
      final document = EditorDocument.fromJson(_deck());
      final slots = document.masterSlots(0);
      expect(slots, hasLength(2));
      expect(slots[0].slot, 'title');
      expect(slots[0].fillId, 'el-t');
      // The fill has no transform, so the placeholder's shows through.
      expect(slots[0].transform, {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2});
      expect(slots[0].style, {'fontSize': 40});
      expect(slots[1].slot, 'media');
      expect(slots[1].fillId, isNull);
      expect(slots[1].transform, isNull);
      expect(document.masterSlots(1), isEmpty);
    });

    test('a fill transform wins over the placeholder in masterSlots', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).setTransform('el-t', {'x': 0.1, 'y': 0.1, 'w': 0.3, 'h': 0.1});
      expect(document.masterSlots(0)[0].transform, {'x': 0.1, 'y': 0.1, 'w': 0.3, 'h': 0.1});
    });

    test('fillSlotOf names the slot a fill fills', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.fillSlotOf('el-t'), 'title');
      expect(document.fillSlotOf('el-top'), isNull);
      expect(document.fillSlotOf('nope'), isNull);
    });

    test('fillIdsInScene lists fills in slot order', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.fillIdsInScene(0), ['el-t']);
      expect(document.fillIdsInScene(1), isEmpty);
    });
  });

  group('setMasterJson', () {
    test('writes a master and moves the render digest', () {
      final document = EditorDocument.fromJson(_deck());
      final before = document.renderDigest;
      final next = document.setMasterJson('title', {
        'children': [
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.4, 'w': 0.7, 'h': 0.2},
          },
          {'type': 'Placeholder', 'slot': 'media'},
        ],
      });
      expect(next.renderDigest, isNot(before));
      expect(next.masterJson('title')!['children']! as List, hasLength(2));
      expect(document.masterJson('title')!['background'], isNotNull, reason: 'immutable');
    });

    test('adds a new master to a deck without any', () {
      final document = EditorDocument.fromJson(_blankDeck());
      final next = document.setMasterJson('base', {
        'children': [
          {'type': 'Placeholder', 'slot': 'title'},
        ],
      });
      expect(next.masterNames, ['base']);
    });

    test('removing an adopted master fails loudly', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.setMasterJson('title', null), throwsA(anything));
    });

    test('removing the last unadopted master drops the block', () {
      final document = EditorDocument.fromJson(_deck()).detachMaster(0);
      final next = document.setMasterJson('title', null).setMasterJson('closing', null);
      expect(next.toJson().containsKey('masters'), isFalse);
    });
  });

  group('fillSlot', () {
    test('writes the fill under its slot', () {
      final document = EditorDocument.fromJson(_deck()).fillSlot(0, 'media', {
        'id': 'el-m',
        'type': 'Image',
        'source': {'kind': 'asset', 'value': 'a.png'},
      });
      expect(document.fillIdsInScene(0), ['el-t', 'el-m']);
      expect(document.elementJson('el-m')!['type'], 'Image');
      expect(document.fillSlotOf('el-m'), 'media');
    });

    test('an unknown slot fails loudly', () {
      final document = EditorDocument.fromJson(_deck());
      expect(
        () => document.fillSlot(0, 'nope', {'id': 'el-x', 'type': 'Text', 'text': 'x'}),
        throwsA(anything),
      );
    });

    test('a slide without a master cannot take fills', () {
      final document = EditorDocument.fromJson(_deck());
      expect(
        () => document.fillSlot(1, 'title', {'id': 'el-x', 'type': 'Text', 'text': 'x'}),
        throwsA(anything),
      );
    });
  });

  group('fills through the element mutations', () {
    test('setTransform reaches a fill', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).setTransform('el-t', {'x': 0.2, 'y': 0.2, 'w': 0.5, 'h': 0.2});
      expect(document.elementJson('el-t')!['transform'], {
        'x': 0.2,
        'y': 0.2,
        'w': 0.5,
        'h': 0.2,
      });
    });

    test('replaceElement reaches a fill and keeps its id', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).replaceElement('el-t', {'type': 'Text', 'text': 'Rewritten'});
      expect(document.elementJson('el-t')!['text'], 'Rewritten');
      expect(document.fillSlotOf('el-t'), 'title');
    });

    test('removeElement unfills the slot and drops an empty fills map', () {
      final document = EditorDocument.fromJson(_deck()).removeElement('el-t');
      expect(document.elementJson('el-t'), isNull);
      expect(document.sceneJson(0).containsKey('fills'), isFalse);
      expect(document.sceneMasterName(0), 'title', reason: 'the adoption stays');
    });

    test('an unknown id still fails loudly', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.removeElement('nope'), throwsArgumentError);
    });
  });

  group('applyMaster', () {
    test('adopts a master on a freeform slide', () {
      final document = EditorDocument.fromJson(_deck()).applyMaster(1, 'closing');
      expect(document.sceneMasterName(1), 'closing');
      expect(document.sceneJson(1).containsKey('fills'), isFalse);
    });

    test('keeps fills whose slots the new master defines', () {
      final document = EditorDocument.fromJson(_deck()).applyMaster(0, 'closing');
      expect(document.sceneMasterName(0), 'closing');
      expect(document.fillSlotOf('el-t'), 'title');
    });

    test('promotes orphaned fills to scene children with their resolved look', () {
      final withMedia = EditorDocument.fromJson(_deck()).fillSlot(0, 'media', {
        'id': 'el-m',
        'type': 'Image',
        'source': {'kind': 'asset', 'value': 'a.png'},
      });
      final document = withMedia.applyMaster(0, 'closing');
      // 'closing' has no media slot: the fill becomes a plain scene child.
      expect(document.fillSlotOf('el-m'), isNull);
      final ids = document.elementIdsInScene(0);
      expect(ids, contains('el-m'));
      expect(ids.last, 'el-m', reason: 'promoted on top');
      // No transform anywhere: the promoted child lands centered.
      expect(document.elementJson('el-m')!['transform'], {'x': 0.5, 'y': 0.5});
    });

    test('a promoted fill inherits the old placeholder transform and style', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).setMasterJson('plain', {'children': <Object?>[]}).applyMaster(0, 'plain');
      expect(document.fillSlotOf('el-t'), isNull);
      final promoted = document.elementJson('el-t')!;
      expect(promoted['transform'], {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2});
      expect(promoted['style'], {'fontSize': 40});
    });

    test('an unknown master fails loudly', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.applyMaster(0, 'nope'), throwsArgumentError);
    });
  });

  group('detachMaster', () {
    test('drops the adoption and promotes every fill', () {
      final document = EditorDocument.fromJson(_deck()).detachMaster(0);
      expect(document.sceneMasterName(0), isNull);
      expect(document.sceneJson(0).containsKey('fills'), isFalse);
      final promoted = document.elementJson('el-t')!;
      expect(promoted['transform'], {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2});
      expect(promoted['style'], {'fontSize': 40});
      expect(document.elementIdsInScene(0), ['el-top', 'el-t']);
    });

    test('a fill style wins over the placeholder style per field', () {
      final styled = EditorDocument.fromJson(_deck()).replaceElement('el-t', {
        'type': 'Text',
        'text': 'Styled',
        'style': {'fontSize': 12, 'color': '#FF0000'},
      });
      final document = styled.detachMaster(0);
      expect(document.elementJson('el-t')!['style'], {'fontSize': 12, 'color': '#FF0000'});
    });

    test('detaching a freeform slide is a no-op shape-wise', () {
      final document = EditorDocument.fromJson(_deck()).detachMaster(1);
      expect(document.sceneMasterName(1), isNull);
    });
  });
}

Map<String, Object?> _blankDeck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {'duration': '60f', 'children': <Object?>[]},
  ],
};
