// What a video-timeline drag can catch on. The candidates come from the same
// model the lanes are drawn from, so a bar can only snap to something the
// author can actually see.

import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const _palette = VideoLanePalette(
  scene: Color(0xFF46A758),
  element: Color(0xFF0090FF),
  music: Color(0xFF30A46C),
  sfx: Color(0xFFFFB224),
);

/// Two scenes of 60 and 90 frames; scene 0 holds a clip windowed 10..40 and
/// scene 1 a second clip, so the boundary sits at 60 and the clips give bar
/// edges at 10, 40, 70 and 100.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'a',
          'type': 'Text',
          'text': 'one',
          'show': {'from': '10f', 'to': '40f'},
        },
      ],
    },
    {
      'duration': '90f',
      'children': [
        {
          'id': 'b',
          'type': 'Text',
          'text': 'two',
          'show': {'from': '10f', 'to': '40f'},
        },
      ],
    },
  ],
};

VideoLaneModel _model() =>
    VideoLaneModel.build(document: EditorDocument.fromJson(_deck()), palette: _palette);

TimelineSnapEngine _engine({String draggedBarId = 'el:a', int playhead = 0}) => videoLaneSnapEngine(
  _model(),
  draggedBarId: draggedBarId,
  playhead: playhead,
  pixelsPerFrame: 2,
);

void main() {
  group('the tolerance', () {
    test('is a pixel budget expressed in frames, so it feels the same at any zoom', () {
      expect(snapToleranceFrames(2), 4);
      expect(snapToleranceFrames(8), 1);
    });

    test('never falls below a frame, however far in the timeline is zoomed', () {
      // A zero tolerance would make snapping unreachable by hand at high zoom,
      // which reads as the feature being broken rather than precise.
      expect(snapToleranceFrames(64), 1);
      expect(snapToleranceFrames(1000), 1);
    });
  });

  group('what a drag catches on', () {
    test('the scene boundary', () {
      expect(_engine().snap(62).frame, 60);
      expect(_engine().snap(62).candidate!.kind, TimelineSnapKind.sceneBoundary);
    });

    test('another bar edge', () {
      // Scene 1 starts at 60, so bar b runs 70..100.
      final result = _engine().snap(68);

      expect(result.frame, 70);
      expect(result.candidate!.kind, TimelineSnapKind.barEdge);
    });

    test('the playhead', () {
      final result = _engine(playhead: 123).snap(121);

      expect(result.frame, 123);
      expect(result.candidate!.kind, TimelineSnapKind.playhead);
    });

    test('frame zero, reported as what it is — the first scene beginning', () {
      // The video's start and scene zero's start are one line, so it names the
      // boundary rather than a second anchor at the same frame that would only
      // fight it for the tie.
      final result = _engine(playhead: 200).snap(2);

      expect(result.frame, 0);
      expect(result.candidate!.kind, TimelineSnapKind.sceneBoundary);
    });
  });

  group('what it must not catch on', () {
    test('itself', () {
      // Bar a runs 10..40 and is the one being dragged: a bar that snapped to
      // its own edges could never be nudged off them.
      final kinds = [
        for (final frame in const [11, 39]) _engine().snap(frame).candidate?.kind,
      ];

      expect(kinds, isNot(contains(TimelineSnapKind.barEdge)));
    });

    test('a scene block read as a bar edge', () {
      // The scenes lane draws one block per scene. Those frames are boundaries
      // and must report as boundaries, or the tie order would rank the label a
      // user never placed above the cut they did.
      expect(_engine().snap(60).candidate!.kind, TimelineSnapKind.sceneBoundary);
      expect(_engine().snap(150).candidate!.kind, TimelineSnapKind.sceneBoundary);
    });

    test('nothing at all, when the drag is nowhere near', () {
      expect(_engine().snap(126).snapped, isFalse);
    });
  });

  group('a bar dragged as a whole', () {
    test('catches on its trailing edge too', () {
      // A 30-frame bar dragged so it ends near the boundary at 60 lands so the
      // end is exactly on it.
      final result = _engine().snapBar(28, length: 30);

      expect(result.frame, 30, reason: 'so the end lands on 60');
    });
  });
}
