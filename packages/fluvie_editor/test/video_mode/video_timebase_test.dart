import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show FrameSpan, introspectTimeline;
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
      ],
    },
    {
      'duration': '60f',
      'children': [
        {'id': 'el-c', 'type': 'Text', 'text': 'c'},
      ],
    },
  ],
};

/// A deck whose scene 1 carries an overlapping `slide` enter (its blend
/// displaces the scene until the overlap ends) and whose scene 2 carries a
/// 30-frame entrance animation.
Map<String, Object?> _transitionDeck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    {
      'duration': '60f',
      'enter': {'kind': 'slide', 'duration': '15f'},
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
      ],
    },
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-c',
          'type': 'Text',
          'text': 'c',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
  ],
};

void main() {
  group('VideoTimebase', () {
    test('reads fps, total frames, and scene spans off the introspection', () {
      final timebase = VideoTimebase.of(EditorDocument.fromJson(_deck()));
      expect(timebase.fps, 30);
      expect(timebase.totalFrames, 270);
      expect(timebase.sceneSpans, const [
        FrameSpan(0, 120),
        FrameSpan(120, 210),
        FrameSpan(210, 270),
      ]);
    });

    test('sceneAt maps any frame to the scene under it, clamped to the video', () {
      final timebase = VideoTimebase.of(EditorDocument.fromJson(_deck()));
      expect(timebase.sceneAt(0), 0);
      expect(timebase.sceneAt(119), 0);
      expect(timebase.sceneAt(120), 1);
      expect(timebase.sceneAt(209), 1);
      expect(timebase.sceneAt(210), 2);
      expect(timebase.sceneAt(500), 2);
      expect(timebase.sceneAt(-5), 0);
    });

    test('settleFrameOf lands past the incoming transition and the entrance', () {
      final timebase = VideoTimebase.of(EditorDocument.fromJson(_transitionDeck()));
      expect(timebase.sceneSpans, const [
        FrameSpan(0, 60),
        FrameSpan(45, 105),
        FrameSpan(105, 165),
      ]);

      // Scene 0: no incoming transition, no entrance — settled at its start.
      expect(timebase.settleFrameOf(0), 0);
      expect(timebase.settleFrameOf(0), timebase.sceneSpans[0].start);

      // Scene 1: the overlapping slide blend displaces it until the window
      // ends at the predecessor's span end — past the scene's own start,
      // which is where the old seek parked mid-transition.
      expect(timebase.settleFrameOf(1), 60);
      expect(timebase.settleFrameOf(1), timebase.sceneSpans[0].end);
      expect(timebase.settleFrameOf(1), greaterThan(timebase.sceneSpans[1].start));

      // Scene 2: a 30-frame entrance settles the elements past the start.
      expect(timebase.settleFrameOf(2), 135);
      expect(timebase.settleFrameOf(2), greaterThan(timebase.sceneSpans[2].start));
    });

    test('settleFrameOf clamps the scene index like sceneAt', () {
      final timebase = VideoTimebase.of(EditorDocument.fromJson(_transitionDeck()));
      expect(timebase.settleFrameOf(-3), timebase.settleFrameOf(0));
      expect(timebase.settleFrameOf(9), timebase.settleFrameOf(2));
    });

    test('the one time mapping: slides math and video math agree per element', () {
      // The law: the absolute frame the video mode computes for a local
      // slide frame equals scene.span.start + local — both sides read the
      // SAME introspection the renderer resolves, so they cannot drift.
      final document = EditorDocument.fromJson(_deck());
      final timebase = VideoTimebase.of(document);
      final introspection = introspectTimeline(document.spec.build());
      for (var scene = 0; scene < 3; scene++) {
        final span = introspection.scenes[scene].span;
        expect(timebase.sceneSpans[scene], span);
        const local = 10;
        final absolute = timebase.sceneSpans[scene].start + local;
        expect(timebase.sceneAt(absolute), scene);
        expect(absolute - span.start, local);
      }
    });
  });
}
