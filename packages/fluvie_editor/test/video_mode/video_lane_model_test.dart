import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show FrameSpan;
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
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
        },
        {
          'id': 'el-win',
          'type': 'Text',
          'text': 'windowed',
          'show': {'from': '30f', 'to': '90f'},
        },
        {'id': 'el-plain', 'type': 'Text', 'text': 'canvas only'},
        {
          'id': 'el-grp',
          'type': 'Group',
          'children': [
            {
              'id': 'el-nested',
              'type': 'Text',
              'text': 'nested',
              'show': {'from': '40f', 'to': '70f'},
            },
          ],
        },
      ],
    },
    {
      'duration': '90f',
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'audio/scene.mp3'},
          'trim': {'from': '0f', 'to': '40f'},
        },
      ],
      'children': [
        {
          'id': 'el-clip2',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/outro.mp4'},
          'show': {'from': '10f', 'to': '50f'},
        },
      ],
    },
  ],
};

VideoLaneModel _model([Map<String, Object?>? deck]) =>
    VideoLaneModel.build(document: EditorDocument.fromJson(deck ?? _deck()), palette: _palette);

TimelineBar _bar(VideoLaneModel model, String id) =>
    model.tracks.expand((track) => track.bars).firstWhere((bar) => bar.id == id);

void main() {
  group('VideoLaneModel', () {
    test('the scenes lane heads the timeline with one block per scene', () {
      final model = _model();
      final scenes = model.tracks.first;
      expect(scenes.id, 'scenes');
      expect(scenes.label, 'Scenes');
      expect(scenes.bars.map((bar) => bar.id), ['scene:0', 'scene:1']);
      expect(_bar(model, 'scene:0').start, 0);
      expect(_bar(model, 'scene:0').end, 120);
      expect(_bar(model, 'scene:1').start, 120);
      expect(_bar(model, 'scene:1').end, 210);
      expect(_bar(model, 'scene:0').badge, 'Slide 1');
      expect(_bar(model, 'scene:1').color, _palette.scene);
    });

    test('scene boundaries ride the ruler as markers', () {
      final model = _model();
      expect(model.markers.map((marker) => marker.id), ['boundary:1']);
      expect(model.markers.single.frame, 120);
    });

    test('clips and windowed elements get lanes on absolute frames; plain elements stay off', () {
      final model = _model();
      final laneIds = model.tracks.map((track) => track.id).toList();
      expect(laneIds, isNot(contains('el-track:el-plain')));
      expect(laneIds, isNot(contains('el-track:el-grp')));

      // A window-less clip is alive its whole scene.
      expect(_bar(model, 'el:el-clip').start, 0);
      expect(_bar(model, 'el:el-clip').end, 120);
      // The introspected window IS the lane read (scene 0 starts at 0).
      expect(_bar(model, 'el:el-win').start, 30);
      expect(_bar(model, 'el:el-win').end, 90);
      // A nested window resolves scene-relative (the introspection law).
      expect(_bar(model, 'el:el-nested').start, 40);
      expect(_bar(model, 'el:el-nested').end, 70);
      // Scene 2's clip window offsets by the scene start: 120 + 10..50.
      expect(_bar(model, 'el:el-clip2').start, 130);
      expect(_bar(model, 'el:el-clip2').end, 170);
      expect(_bar(model, 'el:el-clip2').color, _palette.element);
    });

    test('element lanes bind back to their document element and scene', () {
      final model = _model();
      final binding = model.elementBars['el:el-clip2']!;
      expect(binding.elementId, 'el-clip2');
      expect(binding.scene, 1);
      expect(binding.sceneSpan, const FrameSpan(120, 210));
      expect(binding.window, const FrameSpan(130, 170));
      expect(binding.hasWindow, isTrue);
      expect(model.elementBars['el:el-clip']!.hasWindow, isFalse);
    });

    test('audio lanes: video tracks span from at or zero with trim length', () {
      final model = _model();
      // An untrimmed bed plays for its owner: the whole video.
      expect(_bar(model, 'audio:v:0').start, 0);
      expect(_bar(model, 'audio:v:0').end, 210);
      expect(_bar(model, 'audio:v:0').color, _palette.music);
      expect(_bar(model, 'audio:v:0').badge, 'music');
      // A trimmed bed plays its trim length from the owner start.
      expect(_bar(model, 'audio:v:1').start, 0);
      expect(_bar(model, 'audio:v:1').end, 60);
      // A time-placed effect starts at its trigger and draws one nominal
      // second (no prober yet).
      expect(_bar(model, 'audio:v:2').start, 20);
      expect(_bar(model, 'audio:v:2').end, 50);
      expect(_bar(model, 'audio:v:2').color, _palette.sfx);
      // A trigger-placed effect sits at the owner start, badged by its
      // trigger kind.
      expect(_bar(model, 'audio:v:3').start, 0);
      expect(_bar(model, 'audio:v:3').badge, 'beat');
    });

    test('scene audio tracks offset by their scene start', () {
      final model = _model();
      expect(_bar(model, 'audio:s:1:0').start, 120);
      expect(_bar(model, 'audio:s:1:0').end, 160);
    });

    test('audio lanes bind back to their list, index, and shapes', () {
      final model = _model();
      final trimmed = model.audioBars['audio:v:1']!;
      expect(trimmed.scene, isNull);
      expect(trimmed.index, 1);
      expect(trimmed.isSfx, isFalse);
      expect(trimmed.span, const FrameSpan(0, 60));
      expect(trimmed.trimFromFrames, 30);
      expect(trimmed.trimToFrames, 90);
      expect(trimmed.at, VideoAudioAt.ownerStart);

      final timed = model.audioBars['audio:v:2']!;
      expect(timed.isSfx, isTrue);
      expect(timed.at, VideoAudioAt.time);
      expect(timed.trimFromFrames, isNull);

      expect(model.audioBars['audio:v:3']!.at, VideoAudioAt.trigger);

      final scoped = model.audioBars['audio:s:1:0']!;
      expect(scoped.scene, 1);
      expect(scoped.index, 0);
      expect(scoped.span, const FrameSpan(120, 160));
    });

    test('labels name elements like the layers panel and audio by file name', () {
      final model = _model();
      TimelineTrack track(String id) => model.tracks.firstWhere((track) => track.id == id);
      expect(track('el-track:el-clip').label, 'Clip');
      expect(track('el-track:el-win').label, 'Text');
      expect(track('audio-track:v:0').label, 'bed.mp3');
      expect(track('audio-track:s:1:0').label, 'scene.mp3 (slide 2)');
    });

    test('lane order: scenes, then elements scene by scene topmost first, then audio', () {
      final model = _model();
      expect(model.tracks.map((track) => track.id), [
        'scenes',
        'el-track:el-nested',
        'el-track:el-win',
        'el-track:el-clip',
        'el-track:el-clip2',
        'audio-track:v:0',
        'audio-track:v:1',
        'audio-track:v:2',
        'audio-track:v:3',
        'audio-track:s:1:0',
      ]);
    });

    test('carries the timebase and knows an empty timeline', () {
      final model = _model();
      expect(model.fps, 30);
      expect(model.totalFrames, 210);
      expect(model.timebase.sceneAt(150), 1);
      expect(model.hasLanes, isTrue);

      final bare = _model({
        'fluvieSpec': 1,
        'size': {'width': 320, 'height': 180},
        'fps': 30,
        'scenes': [
          {
            'duration': '60f',
            'children': [
              {'id': 'el-a', 'type': 'Text', 'text': 'a'},
            ],
          },
        ],
      });
      expect(bare.hasLanes, isFalse);
      expect(bare.tracks.map((track) => track.id), ['scenes']);
    });
  });
}
