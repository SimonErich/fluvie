import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// The masters identity guardrail: placeholder-filled elements are elements
/// in the scene's OWN json (the `fills` map), so they get stable ids on
/// load like any other element, the id namespace covers them, and the ids
/// ride the scene through reordering and undo.
Map<String, Object?> _deck({Map<String, Object?>? titleFill}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'masters': {
    'content': {
      'children': [
        {'type': 'Box', 'color': '#FF6C5CE7'},
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3},
        },
      ],
    },
  },
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'type': 'Text', 'text': 'freeform'},
      ],
    },
    {
      'duration': '90f',
      'master': 'content',
      'fills': {
        'title': titleFill ?? const {'type': 'Text', 'text': 'adopted', 'anchor': 'headline'},
      },
    },
  ],
};

Map<String, Object?> _fill(EditorDocument doc, int scene) =>
    ((doc.sceneJson(scene)['fills']! as Map)['title']! as Map).cast<String, Object?>();

void main() {
  test('a fill without an id gets one minted on load', () {
    final doc = EditorDocument.fromJson(_deck());
    final fill = _fill(doc, 1);
    expect(fill['id'], isA<String>());
    expect(fill['id'], isNot(doc.elementIdsInScene(0).single), reason: 'ids stay distinct');
  });

  test('minted ids never collide with a fill id, and fills join the lookup', () {
    final doc = EditorDocument.fromJson(
      _deck(titleFill: const {'id': 'el-1', 'type': 'Text', 'text': 'x'}),
    );
    expect(doc.elementIdsInScene(0).single, isNot('el-1'), reason: 'el-1 is taken by the fill');
    expect(doc.nextId(), isNot('el-1'));
    expect(doc.sceneOfElement('el-1'), 1);
    expect(doc.elementJson('el-1')?['text'], 'x');
  });

  test('a fill anchor counts into the anchor namespace', () {
    final doc = EditorDocument.fromJson(_deck());
    expect(doc.anchorIds, contains('headline'));
  });

  test('fill ids survive scene reordering and undo', () {
    final doc = EditorDocument.fromJson(_deck());
    final id = _fill(doc, 1)['id']! as String;
    final history = DocumentHistory(doc)..dispatch(const ReorderSceneCommand(from: 1, to: 0));
    expect(_fill(history.document, 0)['id'], id, reason: 'the fill rides its scene');
    expect(history.document.sceneOfElement(id), 0);
    history.undo();
    expect(_fill(history.document, 1)['id'], id, reason: 'undo restores, identity intact');
    expect(history.document.sceneOfElement(id), 1);
    expect(history.document.renderDigest, doc.renderDigest, reason: 'undo is a full restore');
  });
}
