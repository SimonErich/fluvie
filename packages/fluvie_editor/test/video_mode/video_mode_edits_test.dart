import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const _palette = VideoLanePalette(
  scene: Color(0xFF8E4EC6),
  element: Color(0xFF0091FF),
  music: Color(0xFF46A758),
  sfx: Color(0xFFFFB224),
);

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
    },
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/voice.mp3'},
      'trim': {'from': '30f', 'to': '90f'},
    },
    {
      'kind': 'sfx',
      'source': {'kind': 'asset', 'value': 'audio/whoosh.wav'},
      'at': {'kind': 'at', 'time': '20f'},
    },
    {
      'kind': 'sfx',
      'source': {'kind': 'asset', 'value': 'audio/hit.wav'},
      'at': {'kind': 'beat'},
    },
  ],
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'a',
          'show': {'from': '0f', 'to': '30f'},
        },
        {
          'id': 'el-group',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.6, 'h': 0.6},
          'show': {'from': '0f', 'to': '40f'},
          'children': [
            {
              'id': 'el-child',
              'type': 'Text',
              'text': 'inside',
              'show': {'from': '5f', 'to': '25f'},
            },
          ],
        },
      ],
    },
    {
      'duration': '90f',
      'steps': [
        {
          'elements': ['el-clip'],
        },
      ],
      'audio': [
        {
          'kind': 'sfx',
          'source': {'kind': 'asset', 'value': 'audio/scene.wav'},
        },
      ],
      'children': [
        {
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
          'show': {'from': '10f', 'to': '50f'},
        },
        {
          'id': 'el-full',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/full.mp4'},
        },
      ],
    },
  ],
};

VideoLaneModel _model(EditorDocument document) =>
    VideoLaneModel.build(document: document, palette: _palette);

void main() {
  late EditorDocument document;
  late VideoLaneModel model;

  setUp(() {
    document = EditorDocument.fromJson(_deck());
    model = _model(document);
  });

  group('element lane moves', () {
    test('a move shifts the show window, written scene-relative in frames', () {
      // el-clip: absolute 130..170 inside scene 120..210.
      final edit = videoBarMoved(model, 'el:el-clip', 140, mergeGroup: 'd')!;
      expect(edit.note, isNull);
      final command = edit.command! as SetShowWindowCommand;
      expect(command.mergeGroup, 'd');
      final next = command.apply(document);
      expect(next.elementJson('el-clip')!['show'], {'from': '20f', 'to': '60f'});
    });

    test('a drag past the video end clamps inside the last slide and says so', () {
      final edit = videoBarMoved(model, 'el:el-clip', 300)!;
      expect(edit.note, 'Clamped at the video end.');
      final next = edit.command!.apply(document);
      expect(next.elementJson('el-clip')!['show'], {'from': '50f', 'to': '90f'});
      // Already against the edge: nothing left to move, refused outright.
      final pinned = _model(next);
      final refused = videoBarMoved(pinned, 'el:el-clip', 300)!;
      expect(refused.command, isNull);
      expect(refused.note, 'Clamped at the video end.');
    });

    test('a drag past the video start clamps at frame zero and says so', () {
      // el-a sits at 0..30 in slide 1; there is nothing left of frame 0.
      final edit = videoBarMoved(model, 'el:el-a', -20)!;
      expect(edit.command, isNull);
      expect(edit.note, 'Clamped at the video start.');
    });

    test('an end poking past a middle boundary clamps with the cross-scene hint', () {
      // el-a dragged to 100..130: the start stays in slide 1 (120f long),
      // so the window clamps at the boundary instead of changing slides.
      final edit = videoBarMoved(model, 'el:el-a', 100)!;
      expect(
        edit.note,
        'Clamped at the slide edge; drag the bar start into the next slide to move it.',
      );
      final next = edit.command!.apply(document);
      expect(next.elementJson('el-a')!['show'], {'from': '90f', 'to': '120f'});
    });
  });

  group('cross-scene element moves', () {
    test('a bar dragged into another scene moves the element there', () {
      // el-clip (abs 130..170, slide 2) dragged to start 40: slide 1 holds
      // frame 40, so the element moves and keeps its absolute position.
      final edit = videoBarMoved(model, 'el:el-clip', 40, mergeGroup: 'd')!;
      final command = edit.command! as MoveElementToSceneCommand;
      expect(command.toScene, 0);
      expect(command.mergeGroup, 'd');
      // The move leaves slide 2's build steps; the note says so.
      expect(edit.note, "Left slide 2's build steps.");
      final next = command.apply(document);
      expect(next.sceneOfElement('el-clip'), 0);
      expect(next.elementJson('el-clip')!['show'], {'from': '40f', 'to': '80f'});
      expect(next.sceneJson(1).containsKey('steps'), isFalse);
    });

    test('a stepless element moves clean, no note', () {
      // el-a (abs 0..30, slide 1) dragged to start 150 inside slide 2.
      final edit = videoBarMoved(model, 'el:el-a', 150)!;
      expect(edit.note, isNull);
      final command = edit.command! as MoveElementToSceneCommand;
      expect(command.toScene, 1);
      final next = command.apply(document);
      expect(next.sceneOfElement('el-a'), 1);
      expect(next.elementJson('el-a')!['show'], {'from': '30f', 'to': '60f'});
    });

    test('a landing that does not fit clamps inside the target slide', () {
      // el-clip dragged to start 110: slide 1 holds frame 110, but the
      // 40-frame window pokes past its end, so the start pulls back to 80.
      final edit = videoBarMoved(model, 'el:el-clip', 110)!;
      expect(edit.note, "Left slide 2's build steps. Clamped inside slide 1.");
      final command = edit.command! as MoveElementToSceneCommand;
      expect(command.fromFrames, 80);
      expect(command.toFrames, 120);
    });

    test('a group moves whole', () {
      final edit = videoBarMoved(model, 'el:el-group', 130)!;
      expect(edit.note, isNull);
      final command = edit.command! as MoveElementToSceneCommand;
      expect(command.toScene, 1);
      final next = command.apply(document);
      expect(next.sceneOfElement('el-group'), 1);
      expect(next.childIdsOfGroup('el-group'), ['el-child']);
    });

    test('a group child refuses: it moves with its group', () {
      final edit = videoBarMoved(model, 'el:el-child', 140)!;
      expect(edit.command, isNull);
      expect(edit.note, 'A grouped element moves with its group.');
    });

    test('a motionless move is a no-op', () {
      expect(videoBarMoved(model, 'el:el-clip', 130), isNull);
    });

    test('scene blocks and unknown bars produce nothing', () {
      expect(videoBarMoved(model, 'scene:0', 40), isNull);
      expect(videoBarMoved(model, 'nope', 40), isNull);
      expect(videoBarResized(model, 'scene:0', 0, 60), isNull);
    });
  });

  group('element lane trims', () {
    test('an edge drag windows the element, clamped to its scene', () {
      final edit = videoBarResized(model, 'el:el-clip', 135, 260)!;
      expect(edit.note, isNull);
      final next = edit.command!.apply(document);
      expect(next.elementJson('el-clip')!['show'], {'from': '15f', 'to': '90f'});
    });

    test('trimming a full-scene clip mints its first window', () {
      final edit = videoBarResized(model, 'el:el-full', 120, 180)!;
      final next = edit.command!.apply(document);
      expect(next.elementJson('el-full')!['show'], {'from': '0f', 'to': '60f'});
    });

    test('an unchanged span is a no-op', () {
      expect(videoBarResized(model, 'el:el-clip', 130, 170), isNull);
    });
  });

  group('audio lane moves', () {
    test('a music bed moves using its owner-relative at time', () {
      final edit = videoBarMoved(model, 'audio:v:0', 40)!;
      final moved = edit.command!.apply(document);
      expect(moved.audioTracksJson().first['at'], {'kind': 'at', 'time': '40f'});
    });

    test('a time-placed sfx move rewrites its at time, owner-relative', () {
      final edit = videoBarMoved(model, 'audio:v:2', 45, mergeGroup: 'd')!;
      final command = edit.command! as SetAudioTrackCommand;
      expect(command.mergeGroup, 'd');
      final next = command.apply(document);
      expect(next.audioTracksJson()[2]['at'], {'kind': 'at', 'time': '45f'});
    });

    test('a scene sfx move writes scene-relative frames', () {
      // audio:s:1:0 sits at the scene start (120); moving to 150 is +30.
      final edit = videoBarMoved(model, 'audio:s:1:0', 150)!;
      final next = edit.command!.apply(document);
      expect(next.audioTracksJson(scene: 1).first['at'], {'kind': 'at', 'time': '30f'});
    });

    test('a trigger-placed sfx refuses: a drag must not destroy the trigger', () {
      final edit = videoBarMoved(model, 'audio:v:3', 40)!;
      expect(edit.command, isNull);
      expect(edit.note, 'This audio track fires on a trigger; a drag would replace it.');
    });
  });

  group('audio lane trims', () {
    test('a right-edge drag on an untrimmed bed mints the trim from zero', () {
      final edit = videoBarResized(model, 'audio:v:0', 0, 80)!;
      final next = edit.command!.apply(document);
      expect(next.audioTracksJson()[0]['trim'], {'from': '0f', 'to': '80f'});
    });

    test('a right-edge drag on a trimmed bed keeps its source start', () {
      final edit = videoBarResized(model, 'audio:v:1', 0, 45)!;
      final next = edit.command!.apply(document);
      expect(next.audioTracksJson()[1]['trim'], {'from': '30f', 'to': '75f'});
    });

    test('a left-edge drag consumes source from an existing trim', () {
      final edit = videoBarResized(model, 'audio:v:1', 10, 60)!;
      final next = edit.command!.apply(document);
      expect(next.audioTracksJson()[1]['trim'], {'from': '40f', 'to': '90f'});
    });

    test('a left-edge drag with no trim is refused: the source end is unknown', () {
      final edit = videoBarResized(model, 'audio:v:0', 10, 210)!;
      expect(edit.command, isNull);
      expect(edit.note, 'Trim the end first; the source length is not known yet.');
    });

    test('an sfx has no trim to drag', () {
      final edit = videoBarResized(model, 'audio:v:2', 20, 80)!;
      expect(edit.command, isNull);
      expect(edit.note, 'A sound effect has no trim.');
    });

    test('an unchanged span is a no-op', () {
      expect(videoBarResized(model, 'audio:v:1', 0, 60), isNull);
    });
  });

  test('every lane edit is one undoable step', () {
    final history = DocumentHistory(document)
      ..dispatch(videoBarMoved(model, 'el:el-clip', 140)!.command!);
    history.dispatch(videoBarResized(_model(history.document), 'audio:v:0', 0, 80)!.command!);
    expect(history.document.elementJson('el-clip')!['show'], {'from': '20f', 'to': '60f'});
    expect(history.document.audioTracksJson()[0]['trim'], {'from': '0f', 'to': '80f'});
    history.undo();
    expect(history.document.audioTracksJson()[0].containsKey('trim'), isFalse);
    history.undo();
    expect(history.document.elementJson('el-clip')!['show'], {'from': '10f', 'to': '50f'});
  });
}
