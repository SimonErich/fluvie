import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/canvas/slide_deriver.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'title',
          'transform': {'x': 0.5, 'y': 0.3},
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
    {
      'duration': '60f',
      'children': [
        {'id': 'el-b', 'type': 'Box', 'color': '#6C5CE7'},
      ],
    },
  ],
};

void main() {
  test('derives a single-scene video sized like the deck', () {
    final doc = EditorDocument.fromJson(_deck());
    final derived = SlideDeriver().derive(doc, 0);
    expect(derived.video.scenes, hasLength(1));
    expect(derived.video.fps, 30);
  });

  test('the settle frame clears the longest entrance', () {
    final doc = EditorDocument.fromJson(_deck());
    expect(SlideDeriver().derive(doc, 0).settleFrame, greaterThanOrEqualTo(30));
    expect(SlideDeriver().derive(doc, 1).settleFrame, greaterThanOrEqualTo(0));
  });

  test('memoizes per slide content, not per document instance', () {
    final deriver = SlideDeriver();
    final doc = EditorDocument.fromJson(_deck());
    final first = deriver.derive(doc, 0);
    expect(identical(deriver.derive(doc, 0), first), isTrue);

    // Editing the OTHER slide keeps this derivation cached.
    final otherEdited = doc.setTransform('el-b', {'x': 0.1, 'y': 0.1});
    expect(identical(deriver.derive(otherEdited, 0), first), isTrue);

    // Editing THIS slide re-derives.
    final thisEdited = doc.setTransform('el-a', {'x': 0.9, 'y': 0.9});
    expect(identical(deriver.derive(thisEdited, 0), first), isFalse);
  });

  test('the cache is capped', () {
    final deriver = SlideDeriver(capacity: 1);
    final doc = EditorDocument.fromJson(_deck());
    final first = deriver.derive(doc, 0);
    deriver.derive(doc, 1);
    expect(identical(deriver.derive(doc, 0), first), isFalse);
  });
}
