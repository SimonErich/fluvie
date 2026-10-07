// An overlay on the canvas: drawn on the slide it is homed to, and nowhere
// else. The canvas answers "what does this frame look like"; the timeline
// answers "when is it alive".

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({Map<String, Object?>? show}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'overlays': [
    {'id': 'ov-logo', 'type': 'Text', 'text': 'logo', 'show': ?show},
  ],
  'scenes': <Object?>[
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
};

EditorDocument _homed(int slide, {Map<String, Object?>? show}) =>
    EditorDocument.fromJson(_deck(show: show)).withOverlayHome('ov-logo', slide);

/// How many overlays the derived stage mounts.
int _overlayCount(DerivedSlide derived) => derived.video.overlays.length;

/// How many children the derived slide's one scene mounts.
int _childCount(DerivedSlide derived) => derived.video.scenes.single.children.length;

void main() {
  test('is drawn on the slide it is homed to', () {
    final derived = SlideDeriver().derive(_homed(1), 1);

    expect(_overlayCount(derived), 1);
  });

  test('is not drawn on any other slide', () {
    final derived = SlideDeriver().derive(_homed(1), 0);

    expect(_overlayCount(derived), 0);
    expect(_childCount(derived), 1, reason: 'the slide keeps its own child');
  });

  test('is drawn nowhere until something homes it', () {
    final document = EditorDocument.fromJson(_deck());

    expect(_overlayCount(SlideDeriver().derive(document, 0)), 0);
    expect(_overlayCount(SlideDeriver().derive(document, 1)), 0);
  });

  test('is drawn whatever its window says, because the stage is one slide', () {
    // Its window is the video's; a stage one slide long would gate it out.
    // The timeline is where an overlay's timing is read.
    final derived = SlideDeriver().derive(_homed(0, show: {'from': '100f', 'to': '140f'}), 0);

    expect(_overlayCount(derived), 1);
  });

  test('re-derives when it changes, rather than serving a stale slide', () {
    // The cache key has to know about the overlays or an edit to one would
    // show the frame as it was.
    final deriver = SlideDeriver();
    final before = deriver.derive(_homed(0), 0);
    final after = deriver.derive(
      _homed(0).replaceElement('ov-logo', {'id': 'ov-logo', 'type': 'Text', 'text': 'changed'}),
      0,
    );

    expect(identical(before, after), isFalse);
  });

  test('a deck with no overlays derives exactly what it derived before', () {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'scenes': <Object?>[
        {
          'duration': '60f',
          'children': [
            {'id': 'el-a', 'type': 'Text', 'text': 'one'},
          ],
        },
      ],
    });

    final derived = SlideDeriver().derive(document, 0);
    expect(_overlayCount(derived), 0);
    expect(_childCount(derived), 1);
  });
}
