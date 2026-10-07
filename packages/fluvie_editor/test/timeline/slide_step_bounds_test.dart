import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorDocument, slideStepBounds;

Map<String, Object?> _deck({List<Object?>? steps, bool animated = true}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '200f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'a',
          if (animated)
            'animate': [
              {'preset': 'fadeIn', 'duration': '30f'},
            ],
        },
        {
          'id': 'el-b',
          'type': 'Text',
          'text': 'b',
          if (animated)
            'animate': [
              {'preset': 'fadeIn', 'delay': '40f', 'duration': '20f'},
            ],
        },
        {
          'id': 'el-c',
          'type': 'Text',
          'text': 'c',
          if (animated)
            'animate': [
              {'preset': 'fadeIn', 'delay': '35f', 'duration': '15f'},
            ],
        },
      ],
      'steps': ?steps,
    },
    {
      'duration': '60f',
      'children': [
        {'id': 'el-d', 'type': 'Text', 'text': 'd'},
      ],
    },
  ],
};

void main() {
  test('a stepped slide yields one landing per click, marker parity first', () {
    // The base (a at 30, c at 50) settles at 50; the b step settles at 60 —
    // the presenter's click landings.
    final document = EditorDocument.fromJson(
      _deck(
        steps: [
          {
            'elements': ['el-b'],
          },
        ],
      ),
    );
    expect(slideStepBounds(document, 0), [50, 60]);
  });

  test('a step-less slide lands once, on the slide settle', () {
    final document = EditorDocument.fromJson(_deck());
    expect(slideStepBounds(document, 0), [60]);
  });

  test('a slide without entrances has no landings', () {
    final document = EditorDocument.fromJson(_deck(animated: false));
    expect(slideStepBounds(document, 1), isEmpty);
  });

  test('non-increasing settles collapse to a strictly increasing ladder', () {
    // c settles at 50, before b's 60: the c click adds no landing of its
    // own and the ladder stays strictly increasing.
    final document = EditorDocument.fromJson(
      _deck(
        steps: [
          {
            'elements': ['el-b'],
          },
          {
            'elements': ['el-c'],
          },
        ],
      ),
    );
    expect(slideStepBounds(document, 0), [30, 60]);
  });

  test('bounds are scene-relative on a later slide', () {
    final document = EditorDocument.fromJson(_deck());
    // Slide 1 has no entrances at all.
    expect(slideStepBounds(document, 1), isEmpty);
  });
}
