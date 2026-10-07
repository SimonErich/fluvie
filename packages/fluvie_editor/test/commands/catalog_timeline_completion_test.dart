import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'lanes': [
    {'id': 'video'},
  ],
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'a',
          'type': 'Clip',
          'lane': 'video',
          'source': {'kind': 'asset', 'value': 'a.mp4'},
          'show': {'from': '0f', 'to': '60f'},
          'trim': {'from': '0s', 'to': '2s'},
        },
        {
          'id': 'b',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'b.mp4'},
          'show': {'from': '60f', 'to': '120f'},
        },
      ],
    },
  ],
};

void main() {
  for (final id in [
    'timeline.razorAll',
    'timeline.lift',
    'timeline.extract',
    'timeline.addLane',
    'timeline.deleteLane',
  ]) {
    test('$id is one undo step with deterministic redo', () async {
      final doc = EditorDocument.fromJson(_deck());
      final history = DocumentHistory(doc);
      final scope = CommandScope(
        document: doc,
        slide: 0,
        dispatch: history.dispatch,
        playhead: 30,
        markIn: 20,
        markOut: 40,
        activeLane: 'video',
        timelineSelection: {'el:a'},
        seek: (_) {},
      );
      final entry = editorCommandById(id);
      expect(entry.enabled(scope), isTrue);
      await entry.execute(scope);
      final changed = history.document.toJson();
      expect(changed, isNot(doc.toJson()));
      if (id == 'timeline.extract') {
        final model = VideoLaneModel.build(document: history.document);
        expect(model.elementBars['el:b']!.window.start, 40);
      }
      if (id == 'timeline.lift') {
        final model = VideoLaneModel.build(document: history.document);
        expect(model.elementBars['el:b']!.window.start, 60);
      }
      if (id == 'timeline.deleteLane') {
        expect(history.document.elementJson('a')!.containsKey('lane'), isFalse);
        expect(history.document.spec.lanes, isEmpty);
      }
      history.undo();
      expect(history.canUndo, isFalse);
      expect(history.document.toJson(), doc.toJson());
      history.redo();
      expect(history.document.toJson(), changed);
      history.dispose();
    });
  }
  test('snapping toggles the shared preference without document mutation', () async {
    var toggled = false;
    final scope = CommandScope(
      document: EditorDocument.fromJson(_deck()),
      slide: 0,
      dispatch: (_) => fail('Not a document edit'),
      toggleSnap: () => toggled = true,
    );
    final entry = editorCommandById('timeline.snap');
    expect(entry.checked!(scope), isTrue);
    await entry.execute(scope);
    expect(toggled, isTrue);
  });
}
