// Retiming a slide from the timeline. A scene's duration is the master clock,
// so a retime moves everything after it — and a duration the engine would
// refuse is refused here, with the engine's own words.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// Two slides of 120 and 90 frames. The clip in slide 0 is windowed 30..90,
/// so a short enough retime has to clamp it.
Map<String, Object?> _deck({Map<String, Object?>? enter}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/a.mp4'},
          'show': {'from': '30f', 'to': '90f'},
        },
      ],
    },
    {
      'duration': '90f',
      'enter': ?enter,
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
};

({EditorDocument document, VideoLaneModel model}) _state(Map<String, Object?> deck) {
  final document = EditorDocument.fromJson(deck);
  return (document: document, model: VideoLaneModel.build(document: document));
}

EditorDocument _applied(VideoLaneEdit edit, EditorDocument document) =>
    edit.command!.apply(document);

void main() {
  group('retiming a slide', () {
    test('writes its new duration', () {
      final state = _state(_deck());

      final edit = videoSceneRetimed(state.model, 0, 150, document: state.document);

      expect(_applied(edit!, state.document).sceneJson(0)['duration'], '150f');
    });

    test('moves everything after it, because a slide length is the master clock', () {
      final state = _state(_deck());

      final document = _applied(
        videoSceneRetimed(state.model, 0, 150, document: state.document)!,
        state.document,
      );

      expect(VideoTimebase.of(document).sceneSpans[1].start, 150);
      expect(VideoTimebase.of(document).totalFrames, 240);
    });

    test('is no edit at all when the duration does not change', () {
      final state = _state(_deck());

      expect(videoSceneRetimed(state.model, 0, 120, document: state.document), isNull);
    });

    test('refuses a slide with no frames in it', () {
      // Zero frames is not a short slide, it is no slide.
      final state = _state(_deck());

      final edit = videoSceneRetimed(state.model, 0, 0, document: state.document);

      expect(edit!.command, isNull);
      expect(edit.note, contains('frame'));
    });

    test('refuses a scene index nothing answers to', () {
      final state = _state(_deck());

      expect(videoSceneRetimed(state.model, 7, 60, document: state.document), isNull);
    });
  });

  group('what the engine would refuse', () {
    test('a slide too short for its own incoming blend, in the engine own words', () {
      // Slide 1 takes a 30-frame crossFade; retimed to 20 frames it cannot
      // hold its own blend head, and the offset resolver says so.
      final state = _state(_deck(enter: {'kind': 'crossFade', 'duration': '30f'}));

      final edit = videoSceneRetimed(state.model, 1, 20, document: state.document);

      expect(edit!.command, isNull);
      expect(edit.note, contains('cannot fit its transitions'));
    });

    test('but allows the same slide once it is long enough', () {
      final state = _state(_deck(enter: {'kind': 'crossFade', 'duration': '30f'}));

      final edit = videoSceneRetimed(state.model, 1, 40, document: state.document);

      expect(edit!.command, isNotNull);
      expect(edit.note, isNull);
    });
  });

  group('the windows inside it', () {
    test('clamp into a shortened slide, and the note names them', () {
      // The clip runs 30..90; a 60-frame slide has no room for its tail.
      final state = _state(_deck());

      final edit = videoSceneRetimed(state.model, 0, 60, document: state.document);
      final document = _applied(edit!, state.document);

      expect(document.elementJson('el-clip')!['show'], {'from': '30f', 'to': '60f'});
      expect(edit.note, contains('el-clip'));
    });

    test('are left alone by a lengthening', () {
      final state = _state(_deck());

      final edit = videoSceneRetimed(state.model, 0, 200, document: state.document);
      final document = _applied(edit!, state.document);

      expect(document.elementJson('el-clip')!['show'], {'from': '30f', 'to': '90f'});
      expect(edit.note, isNull);
    });

    test('are dropped rather than inverted when the slide ends before they start', () {
      // A window whose start is past the new end is not a window at all; the
      // element keeps its place on the canvas and loses its timing.
      final state = _state(_deck());

      final edit = videoSceneRetimed(state.model, 0, 20, document: state.document);
      final document = _applied(edit!, state.document);

      expect(document.elementJson('el-clip')!.containsKey('show'), isFalse);
      expect(edit.note, contains('el-clip'));
    });

    test('are one undo step with the retime, because it was one gesture', () {
      final state = _state(_deck());
      final history = DocumentHistory(state.document)
        ..dispatch(videoSceneRetimed(state.model, 0, 60, document: state.document)!.command!)
        ..undo();

      expect(history.document.sceneJson(0)['duration'], '120f');
      expect(history.document.elementJson('el-clip')!['show'], {'from': '30f', 'to': '90f'});
      expect(history.canUndo, isFalse);
    });
  });
}
