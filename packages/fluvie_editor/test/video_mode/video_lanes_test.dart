// Declared lanes in the video timeline: one row each, material drawn on the
// row it names, and a drag onto another row writing the `lane` key.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// One 120-frame slide with two clips and a bed. `lanes` and each `lane`
/// reference are optional so the same deck exercises both worlds.
Map<String, Object?> _deck({
  bool lanes = true,
  String? clipLane = 'v1',
  String? bedLane = 'a1',
}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
      'lane': ?bedLane,
    },
  ],
  if (lanes)
    'lanes': [
      {'id': 'v1', 'name': 'Video 1'},
      {'id': 'v2', 'name': 'Overlay', 'height': 40},
      {'id': 'a1', 'name': 'Music', 'kind': 'audio', 'muted': true},
    ],
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/a.mp4'},
          'show': {'from': '0f', 'to': '60f'},
          'lane': ?clipLane,
        },
        {
          'id': 'el-b',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/b.mp4'},
          'show': {'from': '60f', 'to': '120f'},
          'lane': ?clipLane,
        },
      ],
    },
  ],
};

({EditorDocument document, VideoLaneModel model}) _state(Map<String, Object?> deck) {
  final document = EditorDocument.fromJson(deck);
  return (document: document, model: VideoLaneModel.build(document: document));
}

TimelineTrack _row(VideoLaneModel model, String id) =>
    model.tracks.firstWhere((track) => track.id == id);

void main() {
  group('the rows', () {
    test('are one per declared lane, in declaration order', () {
      final model = _state(_deck()).model;

      expect(model.tracks.map((t) => t.id).take(4), [
        'scenes',
        'lane:v1',
        'lane:v2',
        'lane:a1',
      ]);
    });

    test('carry the lane name, height and mute', () {
      final model = _state(_deck()).model;

      expect(_row(model, 'lane:v2').label, 'Overlay');
      expect(_row(model, 'lane:v2').height, 40);
      expect(_row(model, 'lane:a1').muted, isTrue);
    });

    test('exist even with nothing on them, because that is where the next clip goes', () {
      expect(_row(_state(_deck()).model, 'lane:v2').bars, isEmpty);
    });

    test('hold every bar that names them', () {
      final model = _state(_deck()).model;

      expect(_row(model, 'lane:v1').bars.map((b) => b.id), ['el:el-b', 'el:el-a']);
      expect(_row(model, 'lane:a1').bars.map((b) => b.id), ['audio:v:0']);
    });

    test('leave material that names no lane on a row of its own', () {
      final model = _state(_deck(clipLane: null, bedLane: null)).model;

      expect(model.tracks.map((t) => t.id), contains('el-track:el-a'));
      expect(_row(model, 'lane:v1').bars, isEmpty);
    });

    test('are absent altogether in a deck that declares none', () {
      // The whole point of additive: a document with no lanes draws exactly
      // the rows it drew before there were lanes at all.
      final model = _state(_deck(lanes: false, clipLane: null, bedLane: null)).model;

      expect(model.tracks.map((t) => t.id), [
        'scenes',
        'el-track:el-b',
        'el-track:el-a',
        'audio-track:v:0',
      ]);
    });
  });

  group('re-laning', () {
    VideoLaneEdit? relane(String row, {Map<String, Object?>? deck, String bar = 'el:el-a'}) {
      final state = _state(deck ?? _deck());
      return videoBarRelaned(state.model, bar, row, document: state.document);
    }

    test('writes the lane the bar was dropped on', () {
      final state = _state(_deck());

      final edit = videoBarRelaned(state.model, 'el:el-a', 'lane:v2', document: state.document);
      final document = edit!.command!.apply(state.document);

      expect(document.elementJson('el-a')!['lane'], 'v2');
      expect(document.elementJson('el-a')!['show'], {'from': '0f', 'to': '60f'});
    });

    test('drops the key when the bar lands on a row of its own', () {
      final state = _state(_deck());

      final edit = videoBarRelaned(
        state.model,
        'el:el-a',
        'el-track:el-b',
        document: state.document,
      );

      expect(
        edit!.command!.apply(state.document).elementJson('el-a')!.containsKey('lane'),
        isFalse,
      );
    });

    test('is no edit at all when the bar lands where it started', () {
      expect(relane('lane:v1'), isNull);
    });

    test('is no edit for material that had no lane and still has none', () {
      expect(
        relane('el-track:el-b', deck: _deck(clipLane: null, bedLane: null)),
        isNull,
      );
    });

    test('reassigns audio without changing its timing or mix order', () {
      final edit = relane('lane:v1', bar: 'audio:v:0');

      expect(edit!.command!.apply(_state(_deck()).document).audioTracksJson().single['lane'], 'v1');
    });

    test('ignores a bar the model does not know', () {
      expect(relane('lane:v1', bar: 'el:nobody'), isNull);
    });
  });

  group('a muted lane', () {
    test('silences the audio that rides it, all the way to the built video', () {
      // The editor draws the mute and the renderer honours it: one document,
      // one answer.
      final state = _state(_deck());

      expect(state.document.spec.build().audio, isEmpty);
    });
  });

  group('an overlay bar', () {
    Map<String, Object?> deckWithOverlay({Map<String, Object?>? show}) => {
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

    test('spans the whole video when it names no window', () {
      final model = _state(deckWithOverlay()).model;

      final bar = _row(model, 'overlay-track:ov-logo').bars.single;
      expect(bar.start, 0);
      expect(bar.end, 150);
    });

    test('spans its own window in absolute frames, crossing the boundary', () {
      // 40..120 on a video whose slides meet at 60: one bar, no seam, and no
      // slide it could be clamped into.
      final model = _state(deckWithOverlay(show: {'from': '40f', 'to': '120f'})).model;

      final bar = _row(model, 'overlay-track:ov-logo').bars.single;
      expect(bar.start, 40);
      expect(bar.end, 120);
    });

    test('binds back to the element with no scene span at all', () {
      final model = _state(deckWithOverlay()).model;

      final binding = model.overlayBars['overlay:ov-logo']!;
      expect(binding.elementId, 'ov-logo');
      expect(binding.window.start, 0);
      expect(binding.home, isNull);
    });

    test('carries its home when the editor block names one', () {
      final document = EditorDocument.fromJson(
        deckWithOverlay(),
      ).withOverlayHome('ov-logo', 1);
      final model = VideoLaneModel.build(document: document);

      expect(model.overlayBars['overlay:ov-logo']!.home, 1);
    });

    test('is enough on its own to make the timeline non-empty', () {
      // A video whose only material is an overlay still has lanes to draw.
      expect(_state(deckWithOverlay()).model.hasLanes, isTrue);
    });
  });
}
