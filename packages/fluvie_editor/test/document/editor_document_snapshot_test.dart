import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _source() => {
  'fluvieSpec': 1,
  'fps': 24,
  'size': {'width': 320, 'height': 180},
  'editor': {
    'editorSchema': 1,
    'deck': {'mode': 'video'},
  },
  'scenes': [
    {
      'duration': '48f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'group',
          'type': 'Group',
          'children': [
            {
              'id': 'child',
              'type': 'Box',
              'color': '#EE0C0C',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.25, 'h': 0.25},
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  test('repeated document reads stay defensive after all lookups are used', () {
    final source = _source();
    final document = EditorDocument.fromJson(source);
    final saved = document.toJson();
    final documentDigest = document.documentDigest;
    final renderDigest = document.renderDigest;
    expect(document.parentGroupOf('child'), 'group');
    expect(document.sceneOfElement('child'), 0);

    source.clear();
    document.toJson().clear();
    (document.sceneJson(0)['children']! as List<Object?>).clear();
    (document.elementJson('group')!['children']! as List<Object?>).clear();
    (document.elementJson('child')!['transform']! as Map<String, Object?>)['x'] = 0;
    document.childIdsOfGroup('group').clear();

    for (var i = 0; i < 3; i++) {
      expect(document.toJson(), saved);
      expect(document.documentDigest, documentDigest);
      expect(document.renderDigest, renderDigest);
      expect(document.childIdsOfGroup('group'), ['child']);
      expect(document.elementJson('child')!['color'], '#EE0C0C');
    }
  });

  test('mutable parsed spec cannot alter canonical JSON, digest or ID ownership', () {
    final document = EditorDocument.fromJson(_source());
    final saved = document.toJson();
    final documentDigest = document.documentDigest;
    final renderDigest = document.renderDigest;
    expect(document.elementJson('child'), isNotNull);

    final parsed = document.spec;
    parsed.editorData!['external'] = true;
    (parsed.scenes.first.children.single.props['children']! as List<Object?>).clear();
    expect(document.renderDigest, isNot(renderDigest), reason: 'Render digest stays live');
    expect(document.toJson(), saved);
    expect(document.documentDigest, documentDigest);
    expect(document.elementJson('child'), isNotNull);
    expect(document.parentGroupOf('child'), 'group');
    expect(document.childIdsOfGroup('group'), ['child']);

    // The public spec retains its existing mutable-list API; only its aliases
    // into the saved snapshot are removed.
    parsed.scenes.clear();
    expect(document.sceneCount, 1);
    expect(document.sceneOfElement('child'), 0);
    expect(document.toJson(), saved);
  });

  test('new snapshots and history keep their own digests and element locations', () {
    final original = EditorDocument.fromJson(_source());
    final originalJson = original.toJson();
    final originalDigest = original.documentDigest;
    final originalRender = original.renderDigest;
    expect(original.elementJson('child'), isNotNull);
    final annotated = original.setElementMeta('child', {'name': 'Subject'});
    expect(annotated.documentDigest, isNot(originalDigest));
    expect(annotated.renderDigest, originalRender);

    final history = DocumentHistory(original);
    addTearDown(history.dispose);
    history.dispatch(
      const SetTransformCommand(
        id: 'child',
        transform: {'x': 0.7, 'y': 0.5, 'w': 0.25, 'h': 0.25},
      ),
    );
    final moved = history.document;
    expect(moved.documentDigest, isNot(originalDigest));
    expect(moved.renderDigest, isNot(originalRender));
    expect(moved.parentGroupOf('child'), 'group');
    final removed = moved.removeElement('child');
    expect(removed.elementJson('child'), isNull);
    expect(removed.childIdsOfGroup('group'), isEmpty);
    expect(moved.elementJson('child'), isNotNull);
    expect(original.toJson(), originalJson);

    history.undo();
    expect(history.document, same(original));
    expect(history.document.documentDigest, originalDigest);
    expect(history.document.renderDigest, originalRender);
    history.redo();
    expect(history.document, same(moved));
    expect(history.document.documentDigest, moved.documentDigest);
    expect(history.document.parentGroupOf('child'), 'group');
  });

  test('media entry inputs and reads cannot mutate nested canonical metadata', () {
    final extra = <String, Object?>{
      'tags': <Object?>['original'],
    };
    final entry = MediaStoreEntry(
      id: 'media-1',
      name: 'Clip',
      kind: MediaStoreKind.video,
      source: {'kind': 'file', 'value': '/clip.mp4', 'extra': extra},
    );
    final document = EditorDocument.fromJson(_source()).addMediaEntry(entry);
    final saved = document.toJson();
    final digest = document.documentDigest;
    (extra['tags']! as List<Object?>).add('outside change');
    final exposed = document.mediaEntries.single.source['extra']! as Map<String, Object?>;
    (exposed['tags']! as List<Object?>).clear();
    expect(document.toJson(), saved);
    expect(document.documentDigest, digest);

    final replaced = document.replaceMediaEntry(entry);
    final replacementJson = replaced.toJson();
    final replacementDigest = replaced.documentDigest;
    (extra['tags']! as List<Object?>).clear();
    expect(replaced.toJson(), replacementJson);
    expect(replaced.documentDigest, replacementDigest);
    expect(replacementDigest, isNot(digest));
    expect(document.toJson(), saved);
  });
}
