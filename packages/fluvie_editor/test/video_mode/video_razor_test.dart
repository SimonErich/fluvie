// The razor: one clip becomes two, cut at the playhead. The halves have to
// play exactly what the original played, or a cut would quietly retime the
// footage either side of it.

import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const _palette = VideoLanePalette(
  scene: Color(0xFF46A758),
  element: Color(0xFF0090FF),
  music: Color(0xFF30A46C),
  sfx: Color(0xFFFFB224),
);

/// One 120-frame scene at 30 fps holding a clip windowed 30..90, plus a music
/// bed so the audio lane exists too.
Map<String, Object?> _deck({
  Map<String, Object?>? trim,
  double? speed,
  bool grouped = false,
  Map<String, Object?>? extra,
}) {
  final clip = <String, Object?>{
    'id': 'el-clip',
    'type': 'Clip',
    'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
    'show': {'from': '30f', 'to': '90f'},
    'trim': ?trim,
    'speed': ?speed,
    ...?extra,
  };
  return {
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
        'duration': '120f',
        'children': [
          if (grouped)
            {
              'id': 'el-group',
              'type': 'Group',
              'children': [clip],
            }
          else
            clip,
        ],
      },
    ],
  };
}

({EditorDocument document, VideoLaneModel model}) _state(Map<String, Object?> deck) {
  final document = EditorDocument.fromJson(deck);
  return (
    document: document,
    model: VideoLaneModel.build(document: document, palette: _palette),
  );
}

/// Razors [barId] at absolute [frame] and returns the outcome.
VideoLaneEdit? _razor(
  Map<String, Object?> deck,
  int frame, {
  String barId = 'el:el-clip',
}) {
  final state = _state(deck);
  return videoBarRazored(state.model, barId, frame, document: state.document);
}

/// The document after razoring [barId] at [frame].
EditorDocument _applied(Map<String, Object?> deck, int frame, {String barId = 'el:el-clip'}) {
  final state = _state(deck);
  final edit = videoBarRazored(state.model, barId, frame, document: state.document)!;
  return edit.command!.apply(state.document);
}

List<Map<String, Object?>> _clips(EditorDocument document) => [
  for (final id in document.elementIdsInScene(0))
    if (document.elementJson(id)!['type'] == 'Clip') document.elementJson(id)!,
];

void main() {
  group('what it refuses', () {
    test('a cut before the clip', () {
      final edit = _razor(_deck(), 20);

      expect(edit!.command, isNull);
      expect(edit.note, contains('playhead'));
    });

    test('a cut after the clip', () {
      expect(_razor(_deck(), 95)!.command, isNull);
    });

    test('a cut exactly on either edge, which would make an empty half', () {
      // Landing on the first or last frame is a miss, not a cut: one half
      // would be nothing at all, which is a delete wearing a razor's clothes.
      expect(_razor(_deck(), 30)!.command, isNull);
      expect(_razor(_deck(), 90)!.command, isNull);
    });

    test('an audio lane, naming what is missing', () {
      final edit = _razor(_deck(), 60, barId: 'audio:v:0');

      expect(edit!.command, isNull);
      expect(edit.note, isNotNull);
    });

    test('a scene block, which is not material', () {
      expect(_razor(_deck(), 60, barId: 'scene:0'), isNull);
    });

    test('an unknown bar', () {
      expect(_razor(_deck(), 60, barId: 'el:nobody'), isNull);
    });

    test('a grouped element stays inside the same group', () {
      final edit = _razor(_deck(grouped: true), 60);

      final document = EditorDocument.fromJson(_deck(grouped: true));
      final split = edit!.command!.apply(document);
      expect(split.parentGroupOf('el-clip'), document.parentGroupOf('el-clip'));
      expect(
        split.parentGroupOf((edit.command! as RazorElementCommand).tailId),
        document.parentGroupOf('el-clip'),
      );
    });

    test('a trim written in source frames, because that needs the source rate', () {
      // Source frames only mean something at the source's own frame rate,
      // which the editor does not know. Guessing it would silently shift the
      // tail; saying so lets the author rewrite the trim in seconds.
      final edit = _razor(_deck(trim: {'from': '30f', 'to': '300f'}), 60);

      expect(edit!.command, isNull);
      expect(edit.note, contains('seconds'));
    });
  });

  group('the two halves', () {
    test('split the window at the cut and leave no gap', () {
      final clips = _clips(_applied(_deck(), 60));

      expect(clips, hasLength(2));
      expect(clips.first['show'], {'from': '30f', 'to': '60f'});
      expect(clips.last['show'], {'from': '60f', 'to': '90f'});
    });

    test('keep the source, the type and everything else the clip carried', () {
      final clips = _clips(_applied(_deck(extra: {'fit': 'cover', 'volume': 0.5}), 60));

      for (final clip in clips) {
        expect(clip['source'], {'kind': 'asset', 'value': 'clips/broll.mp4'});
        expect(clip['fit'], 'cover');
        expect(clip['volume'], 0.5);
      }
    });

    test('take a fresh id for the tail and keep the head where it was', () {
      final document = _applied(_deck(), 60);
      final ids = document.elementIdsInScene(0);

      expect(ids.first, 'el-clip', reason: 'the head keeps the id and its z-position');
      expect(ids, hasLength(2));
      expect(ids.last, isNot('el-clip'));
    });

    test('are one undo step', () {
      final state = _state(_deck());
      final history = DocumentHistory(state.document)
        ..dispatch(
          videoBarRazored(state.model, 'el:el-clip', 60, document: state.document)!.command!,
        );

      expect(_clips(history.document), hasLength(2));

      history.undo();

      expect(_clips(history.document), hasLength(1));
      expect(history.canUndo, isFalse);
    });
  });

  group('the tail picks up where the head left off', () {
    test('a clip with no trim gains one on each half', () {
      // Without a trim the tail would restart the source from its beginning:
      // a jump cut nobody asked for.
      final clips = _clips(_applied(_deck(), 60));

      expect(clips.first['trim'], {'from': '0.0s', 'to': '1.0s'});
      expect(clips.last['trim'], {'from': '1.0s', 'to': '2.0s'});
    });

    test('an existing trim is split at the same instant', () {
      final clips = _clips(_applied(_deck(trim: {'from': '2.0s', 'to': '9.0s'}), 60));

      expect(clips.first['trim'], {'from': '2.0s', 'to': '3.0s'});
      expect(clips.last['trim'], {'from': '3.0s', 'to': '9.0s'});
    });

    test('a doubled speed advances the source twice as fast', () {
      final clips = _clips(_applied(_deck(speed: 2), 60));

      expect(clips.first['trim'], {'from': '0.0s', 'to': '2.0s'});
      expect(clips.last['trim']! as Map<String, Object?>, containsPair('from', '2.0s'));
    });

    test('a half speed advances it half as fast', () {
      final clips = _clips(_applied(_deck(speed: 0.5), 60));

      expect(clips.first['trim'], {'from': '0.0s', 'to': '0.5s'});
    });

    test('a reversed clip splits from the far end', () {
      // Reversed, the window opens on the trim's last frame and walks down,
      // so the head takes the tail of the source and the other way about.
      final clips = _clips(_applied(_deck(trim: {'from': '1.0s', 'to': '9.0s'}, speed: -1), 60));

      expect(clips.first['trim'], {'from': '8.0s', 'to': '9.0s'});
      expect(clips.last['trim'], {'from': '1.0s', 'to': '8.0s'});
    });

    test('a reversed clip with no trim end is refused rather than guessed', () {
      final edit = _razor(_deck(speed: -1), 60);

      expect(edit!.command, isNull);
      expect(edit.note, contains('reversed'));
    });

    test('a cut past a short trim leaves the tail holding the last frame', () {
      // The window outlives the trim, so the original was already holding its
      // last frame at the cut; a zero-length tail trim holds the same one.
      final clips = _clips(_applied(_deck(trim: {'from': '0.0s', 'to': '0.5s'}), 60));

      expect(clips.first['trim'], {'from': '0.0s', 'to': '0.5s'});
      expect(clips.last['trim'], {'from': '0.5s', 'to': '0.5s'});
    });
  });

  group('an element with a window but no source', () {
    test('splits its window and gains no trim', () {
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
                'text': 'hello',
                'show': {'from': '30f', 'to': '90f'},
              },
            ],
          },
        ],
      };

      final document = _applied(deck, 60, barId: 'el:el-text');
      final ids = document.elementIdsInScene(0);

      expect(document.elementJson(ids.first)!['show'], {'from': '30f', 'to': '60f'});
      expect(document.elementJson(ids.last)!['show'], {'from': '60f', 'to': '90f'});
      expect(document.elementJson(ids.last)!.containsKey('trim'), isFalse);
    });
  });
}
