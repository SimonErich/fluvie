// Ripple, roll, slip and slide. Every one of them is defined by what it
// holds still: a ripple holds the gaps closed, a roll holds the pair's outer
// edges, a slip holds the window, a slide holds the content.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// One 200-frame scene at 30 fps with three clips laid end to end:
/// a 0..40, b 40..90, c 90..150, and a gap from 150 to the slide's end.
Map<String, Object?> _deck({
  Map<String, Object?>? trimB,
  double? speedB,
  bool gapAfterA = false,
  bool overlapC = false,
}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
    },
  ],
  'scenes': <Object?>[
    {
      'duration': '200f',
      'children': [
        {
          'id': 'a',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/a.mp4'},
          'show': {'from': '0f', 'to': gapAfterA ? '30f' : '40f'},
        },
        {
          'id': 'b',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/b.mp4'},
          'show': {'from': '40f', 'to': '90f'},
          'trim': ?trimB,
          'speed': ?speedB,
        },
        {
          'id': 'c',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/c.mp4'},
          'show': {'from': overlapC ? '80f' : '90f', 'to': '150f'},
        },
      ],
    },
  ],
};

({EditorDocument document, VideoLaneModel model}) _state(Map<String, Object?> deck) {
  final document = EditorDocument.fromJson(deck);
  return (document: document, model: VideoLaneModel.build(document: document));
}

/// The scene-relative window of [id] after applying [edit].
Map<String, Object?>? _showAfter(
  ({EditorDocument document, VideoLaneModel model}) state,
  VideoLaneEdit? edit,
  String id,
) => edit!.command!.apply(state.document).elementJson(id)?['show'] as Map<String, Object?>?;

void main() {
  group('ripple delete', () {
    test('drops the clip and pulls everything after it back', () {
      final state = _state(_deck());

      final edit = videoRippleDeleted(state.model, {'el:b'}, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('b'), isNull);
      expect(document.elementJson('a')!['show'], {'from': '0f', 'to': '40f'});
      expect(document.elementJson('c')!['show'], {'from': '40f', 'to': '100f'});
    });

    test('closes the gap left by more than one deletion at once', () {
      final state = _state(_deck());

      final edit = videoRippleDeleted(state.model, {'el:a', 'el:b'}, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('c')!['show'], {'from': '0f', 'to': '60f'});
    });

    test('is one undo step however many clips it moved', () {
      final state = _state(_deck());
      final history = DocumentHistory(state.document)
        ..dispatch(videoRippleDeleted(state.model, {'el:b'}, document: state.document)!.command!)
        ..undo();

      expect(history.document.elementJson('b'), isNotNull);
      expect(history.document.elementJson('c')!['show'], {'from': '90f', 'to': '150f'});
      expect(history.canUndo, isFalse);
    });

    test('leaves a clip that overlaps the gap where it is, and says so', () {
      // Pulling back a clip that started inside the deleted span would move it
      // somewhere the author never put it; the honest answer is to close what
      // can be closed and name what did not move.
      final state = _state(_deck(overlapC: true));

      final edit = videoRippleDeleted(state.model, {'el:b'}, document: state.document);

      expect(_showAfter(state, edit, 'c'), {'from': '80f', 'to': '150f'});
      expect(edit!.note, contains('overlap'));
    });

    test('with nothing after it says why the gap stays', () {
      // A slide's length never changes on a ripple, so the gap at the end is
      // real and the author has to be told rather than left looking at it.
      final state = _state(_deck());

      final edit = videoRippleDeleted(state.model, {'el:c'}, document: state.document);

      expect(edit!.command, isNotNull);
      expect(edit.note, contains('length'));
    });

    test('refuses an audio track, which has no window to close', () {
      final state = _state(_deck());

      final edit = videoRippleDeleted(state.model, {'audio:v:0'}, document: state.document);

      expect(edit!.command, isNull);
      expect(edit.note, isNotNull);
    });

    test('ignores a bar the model does not know', () {
      final state = _state(_deck());

      expect(videoRippleDeleted(state.model, {'el:nobody'}, document: state.document), isNull);
    });

    test('does nothing with nothing selected', () {
      final state = _state(_deck());

      expect(videoRippleDeleted(state.model, const {}, document: state.document), isNull);
    });
  });

  group('ripple trim', () {
    test('lengthening the out edge pushes everything after it along', () {
      final state = _state(_deck());

      final edit = videoRippleTrimmed(state.model, 'el:b', 40, 110, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('b')!['show'], {'from': '40f', 'to': '110f'});
      expect(document.elementJson('c')!['show'], {'from': '110f', 'to': '170f'});
    });

    test('shortening it pulls them back', () {
      final state = _state(_deck());

      final edit = videoRippleTrimmed(state.model, 'el:b', 40, 70, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('c')!['show'], {'from': '70f', 'to': '130f'});
    });

    test('trimming the in edge moves nothing, because the end did not move', () {
      // The clip's end is where the next one waits; a head trim leaves it
      // exactly where it was, so a ripple there is just a trim.
      final state = _state(_deck());

      final edit = videoRippleTrimmed(state.model, 'el:b', 50, 90, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('b')!['show'], {'from': '50f', 'to': '90f'});
      expect(document.elementJson('c')!['show'], {'from': '90f', 'to': '150f'});
    });

    test('a push past the slide end clamps and says so', () {
      final state = _state(_deck());

      final edit = videoRippleTrimmed(state.model, 'el:b', 40, 180, document: state.document);

      expect(_showAfter(state, edit, 'c'), {'from': '180f', 'to': '200f'});
      expect(edit!.note, contains('slide'));
    });

    test('an unknown bar does nothing', () {
      final state = _state(_deck());

      expect(
        videoRippleTrimmed(state.model, 'el:nobody', 0, 10, document: state.document),
        isNull,
      );
    });
  });

  group('roll', () {
    test('moves the cut, holding both outer edges', () {
      final state = _state(_deck());

      final edit = videoRolled(state.model, 'el:b', 10, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('b')!['show'], {'from': '40f', 'to': '100f'});
      expect(document.elementJson('c')!['show'], {'from': '100f', 'to': '150f'});
      expect(document.elementJson('a')!['show'], {'from': '0f', 'to': '40f'});
    });

    test('rolls the other way just as well', () {
      final state = _state(_deck());

      final edit = videoRolled(state.model, 'el:b', -10, document: state.document);

      expect(_showAfter(state, edit, 'b'), {'from': '40f', 'to': '80f'});
      expect(_showAfter(state, edit, 'c'), {'from': '80f', 'to': '150f'});
    });

    test('clamps rather than swallowing either clip whole', () {
      // A roll that ate one side would leave a clip with no frames at all,
      // which is a delete the author did not ask for.
      final state = _state(_deck());

      final edit = videoRolled(state.model, 'el:b', 500, document: state.document);

      expect(_showAfter(state, edit, 'b'), {'from': '40f', 'to': '149f'});
      expect(_showAfter(state, edit, 'c'), {'from': '149f', 'to': '150f'});
      expect(edit!.note, isNotNull);
    });

    test('refuses where no clip starts where this one ends', () {
      final state = _state(_deck(gapAfterA: true));

      final edit = videoRolled(state.model, 'el:a', 5, document: state.document);

      expect(edit!.command, isNull);
      expect(edit.note, contains('cut'));
    });

    test('refuses the last clip, which has nothing to roll against', () {
      final state = _state(_deck());

      expect(videoRolled(state.model, 'el:c', 5, document: state.document)!.command, isNull);
    });

    test('a roll of nothing is nothing', () {
      final state = _state(_deck());

      expect(videoRolled(state.model, 'el:b', 0, document: state.document), isNull);
    });
  });

  group('slip', () {
    test('holds the window and moves the source under it', () {
      final state = _state(_deck(trimB: {'from': '2.0s', 'to': '5.0s'}));

      final edit = videoSlipped(state.model, 'el:b', 15, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('b')!['show'], {'from': '40f', 'to': '90f'});
      expect(document.elementJson('b')!['trim'], {'from': '2.5s', 'to': '5.5s'});
    });

    test('slips backwards and stops at the source start', () {
      // There is nothing before the beginning of a file, so a slip that would
      // read past it holds at zero rather than asking for negative footage.
      final state = _state(_deck(trimB: {'from': '0.5s', 'to': '5.0s'}));

      final edit = videoSlipped(state.model, 'el:b', -60, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('b')!['trim'], {'from': '0.0s', 'to': '4.5s'});
      expect(edit.note, isNotNull);
    });

    test('a doubled speed slips the source twice as far', () {
      final state = _state(_deck(trimB: {'from': '2.0s', 'to': '5.0s'}, speedB: 2));

      final edit = videoSlipped(state.model, 'el:b', 15, document: state.document);

      expect(
        edit!.command!.apply(state.document).elementJson('b')!['trim'],
        {'from': '3.0s', 'to': '6.0s'},
      );
    });

    test('refuses a trim it cannot read in seconds', () {
      final state = _state(_deck(trimB: {'from': '30f', 'to': '90f'}));

      final edit = videoSlipped(state.model, 'el:b', 15, document: state.document);

      expect(edit!.command, isNull);
      expect(edit.note, contains('seconds'));
    });

    test('refuses an element with no source to slip', () {
      final deck = {
        'fluvieSpec': 1,
        'size': {'width': 320, 'height': 180},
        'fps': 30,
        'scenes': <Object?>[
          {
            'duration': '120f',
            'children': [
              {
                'id': 'el-text',
                'type': 'Text',
                'text': 'hi',
                'show': {'from': '0f', 'to': '60f'},
              },
            ],
          },
        ],
      };
      final state = _state(deck);

      final edit = videoSlipped(state.model, 'el:el-text', 5, document: state.document);

      expect(edit!.command, isNull);
      expect(edit.note, contains('clip'));
    });

    test('a slip of nothing is nothing', () {
      final state = _state(_deck(trimB: {'from': '2.0s', 'to': '5.0s'}));

      expect(videoSlipped(state.model, 'el:b', 0, document: state.document), isNull);
    });
  });

  group('slide', () {
    test('moves the clip and lets its neighbours absorb it', () {
      final state = _state(_deck());

      final edit = videoSlid(state.model, 'el:b', 10, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('a')!['show'], {'from': '0f', 'to': '50f'});
      expect(document.elementJson('b')!['show'], {'from': '50f', 'to': '100f'});
      expect(document.elementJson('c')!['show'], {'from': '100f', 'to': '150f'});
    });

    test('holds the clip content, which is what makes it a slide', () {
      final state = _state(_deck(trimB: {'from': '2.0s', 'to': '5.0s'}));

      final edit = videoSlid(state.model, 'el:b', 10, document: state.document);

      expect(
        edit!.command!.apply(state.document).elementJson('b')!['trim'],
        {'from': '2.0s', 'to': '5.0s'},
      );
    });

    test('slides against one neighbour when there is only one', () {
      final state = _state(_deck(gapAfterA: true));

      // b has no clip ending where it starts, but c starts where it ends.
      final edit = videoSlid(state.model, 'el:b', 10, document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('b')!['show'], {'from': '50f', 'to': '100f'});
      expect(document.elementJson('c')!['show'], {'from': '100f', 'to': '150f'});
    });

    test('clamps rather than swallowing a neighbour whole', () {
      final state = _state(_deck());

      final edit = videoSlid(state.model, 'el:b', -500, document: state.document);

      expect(_showAfter(state, edit, 'a'), {'from': '0f', 'to': '1f'});
      expect(_showAfter(state, edit, 'b'), {'from': '1f', 'to': '51f'});
      expect(edit!.note, isNotNull);
    });

    test('refuses a clip with no neighbour on either side', () {
      final state = _state(_deck(gapAfterA: true));

      final edit = videoSlid(state.model, 'el:a', 5, document: state.document);

      expect(edit!.command, isNull);
      expect(edit.note, contains('neighbour'));
    });

    test('a slide of nothing is nothing', () {
      final state = _state(_deck());

      expect(videoSlid(state.model, 'el:b', 0, document: state.document), isNull);
    });
  });
}
