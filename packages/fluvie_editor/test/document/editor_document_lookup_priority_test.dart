import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _text(String id, String text) => {'type': 'Text', 'id': id, 'text': text};

EditorDocument _document() => EditorDocument.fromJson({
  'masters': const {
    'layout': {
      'children': [
        {'type': 'Text', 'text': 'master chrome'},
        {'type': 'Placeholder', 'slot': 'content'},
      ],
    },
  },
  'scenes': [
    {
      'duration': '60f',
      'master': 'layout',
      'children': [
        {
          'type': 'Group',
          'id': 'group',
          'children': [_text('duplicate', 'first nested child')],
        },
        _text('duplicate', 'later top-level child'),
        {
          'type': 'Group',
          'id': 'parent-duplicate',
          'children': [_text('parent-duplicate', 'descendant with same id')],
        },
      ],
      'fills': {
        'content': {
          'type': 'Group',
          'id': 'fill',
          'children': [
            _text('duplicate', 'fill with same id'),
            _text('fill-before-scene', 'first scene fill child'),
          ],
        },
      },
    },
    {
      'duration': '60f',
      'children': [
        _text('duplicate', 'second scene'),
        _text('fill-before-scene', 'second scene child'),
      ],
    },
  ],
  'overlays': [
    _text('duplicate', 'overlay with same id'),
    {
      'type': 'Group',
      'id': 'overlay-group',
      'children': [_text('overlay-child', 'nested overlay')],
    },
  ],
});

void main() {
  test('duplicate lookups preserve scene order and depth-first first match', () {
    final document = _document();
    expect(document.elementJson('duplicate')?['text'], 'first nested child');
    expect(document.sceneOfElement('duplicate'), 0);
    expect(document.parentGroupOf('duplicate'), 'group');
    expect(document.elementJson('parent-duplicate')?['type'], 'Group');
    expect(document.parentGroupOf('parent-duplicate'), isNull);
    expect(document.childIdsOfGroup('parent-duplicate'), ['parent-duplicate']);
  });

  test('scene fills and their descendants precede the next scene and overlays', () {
    final document = _document();
    expect(document.elementJson('fill-before-scene')?['text'], 'first scene fill child');
    expect(document.sceneOfElement('fill-before-scene'), 0);
    expect(document.parentGroupOf('fill-before-scene'), 'fill');
    expect(document.childIdsOfGroup('fill'), ['duplicate', 'fill-before-scene']);
    expect(document.elementIdsInScene(0), ['group', 'duplicate', 'parent-duplicate']);
  });

  test('nested overlays retain their parent without acquiring a scene owner', () {
    final document = _document().withOverlayHome('overlay-group', 1);
    expect(document.elementJson('overlay-child')?['text'], 'nested overlay');
    expect(document.parentGroupOf('overlay-child'), 'overlay-group');
    expect(document.sceneOfElement('overlay-child'), isNull);
    expect(document.sceneOfElement('overlay-group'), isNull);
    expect(document.childIdsOfGroup('overlay-group'), ['overlay-child']);
    // isOverlay identifies declared roots, not every descendant on that clock.
    expect(document.isOverlay('overlay-group'), isTrue);
    expect(document.isOverlay('overlay-child'), isFalse);
  });

  test('master names and missing ids do not enter element lookups', () {
    final document = _document();
    for (final id in ['layout', 'missing']) {
      expect(document.elementJson(id), isNull);
      expect(document.sceneOfElement(id), isNull);
      expect(document.parentGroupOf(id), isNull);
      expect(document.childIdsOfGroup(id), isEmpty);
    }
  });

  test('new document states resolve independently of warmed previous lookups', () {
    final original = _document();
    expect(original.elementJson('duplicate')?['text'], 'first nested child');
    expect(original.elementJson('overlay-child'), isNotNull);
    final reordered = original.reorderScene(1, 0);
    expect(reordered.elementJson('duplicate')?['text'], 'second scene');
    expect(reordered.parentGroupOf('duplicate'), isNull);
    expect(reordered.sceneOfElement('duplicate'), 0);
    final removed = reordered.removeOverlay('overlay-group');
    expect(removed.elementJson('overlay-child'), isNull);
    expect(original.elementJson('overlay-child'), isNotNull);
    expect(original.parentGroupOf('duplicate'), 'group');
    expect(original.elementJson('duplicate')?['text'], 'first nested child');
  });
}
