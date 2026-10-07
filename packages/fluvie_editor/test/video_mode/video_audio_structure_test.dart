import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/video_mode/video_audio_structure.dart';
import 'package:fluvie_editor/src/video_mode/video_lift.dart';

Map<String, Object?> music(int at, int from, int to, {String name = 'bed', String? lane}) => {
  'kind': 'music',
  'source': {'kind': 'asset', 'value': 'audio/$name.wav'},
  'at': {'kind': 'at', 'time': '${at}f'},
  'trim': {'from': '${from}f', 'to': '${to}f'},
  'volume': 0.6,
  'lane': ?lane,
};
EditorDocument document({
  List<Map<String, Object?>> audio = const [],
  List<Map<String, Object?>> sceneAudio = const [],
  bool picture = false,
  bool locked = false,
}) => EditorDocument.fromJson({
  'fluvieSpec': 1,
  'fps': 30,
  'size': const {'width': 320, 'height': 180},
  if (locked)
    'lanes': [
      {'id': 'locked', 'kind': 'audio', 'locked': true},
    ],
  'audio': audio,
  'scenes': [
    {
      'duration': '180f',
      'audio': sceneAudio,
      'children': [
        if (picture)
          {
            'id': 'picture',
            'type': 'Text',
            'text': 'Picture',
            'show': {'from': '90f', 'to': '120f'},
          },
      ],
    },
  ],
});
void main() {
  test('razor appends continuous source tail preserving identities with one undo', () {
    final doc = document(
      audio: [
        music(30, 60, 150),
        music(150, 0, 30, name: 'other'),
      ],
    );
    final history = DocumentHistory(doc)
      ..dispatch(
        audioBarRazored(
          VideoLaneModel.build(document: doc),
          'audio:v:0',
          70,
          document: doc,
        )!.command!,
      );
    final audio = history.document.audioTracksJson();
    expect(audio, hasLength(3));
    expect(audio[0]['trim'], {'from': '60f', 'to': '100f'});
    expect(audio[1], doc.audioTracksJson()[1]);
    expect(audio[2]['trim'], {'from': '100f', 'to': '150f'});
    expect(audio[2]['at'], {'kind': 'at', 'time': '70f'});
    expect(audio[2]['volume'], 0.6);
    history.undo();
    expect(history.document.toJson(), doc.toJson());
    expect(history.canUndo, isFalse);
  });
  test('marked lift across positional tracks keeps both tails and exact gap', () {
    final doc = document(
      audio: [
        music(0, 30, 150),
        music(0, 180, 300, name: 'other'),
      ],
    );
    final edit = videoRangeRemoved(VideoLaneModel.build(document: doc), 30, 60, document: doc)!;
    final result = edit.command!.apply(doc);
    expect(result.audioTracksJson().map((track) => track['trim']), [
      {'from': '30f', 'to': '60f'},
      {'from': '180f', 'to': '210f'},
      {'from': '90f', 'to': '150f'},
      {'from': '240f', 'to': '300f'},
    ]);
    expect(
      VideoLaneModel.build(
        document: result,
      ).audioBars.values.map((bar) => (bar.span.start, bar.span.end)),
      [(0, 30), (0, 30), (60, 120), (60, 120)],
    );
  });
  test('marked extract closes owner gaps once without shifting source clock', () {
    final doc = document(
      audio: [
        music(0, 30, 150),
        music(120, 0, 30, name: 'following'),
      ],
    );
    final edit = videoRangeRemoved(
      VideoLaneModel.build(document: doc),
      30,
      60,
      document: doc,
      ripple: true,
    )!;
    final result = edit.command!.apply(doc);
    expect(
      VideoLaneModel.build(
        document: result,
      ).audioBars.values.map((bar) => (bar.span.start, bar.span.end)),
      [(0, 30), (90, 120), (30, 90)],
    );
    expect(result.audioTracksJson().last['trim'], {'from': '90f', 'to': '150f'});
  });
  test('scene audio ripple moves following picture and audio in one owner', () {
    final doc = document(
      sceneAudio: [
        music(30, 0, 30),
        music(90, 30, 60, name: 'following'),
      ],
      picture: true,
    );
    final history = DocumentHistory(doc)
      ..dispatch(
        videoRippleDeleted(VideoLaneModel.build(document: doc), {
          'audio:s:0:0',
        }, document: doc)!.command!,
      );
    expect(history.document.elementJson('picture')!['show'], {'from': '60f', 'to': '90f'});
    expect(history.document.audioTracksJson(scene: 0).single['at'], {'kind': 'at', 'time': '60f'});
    history.undo();
    expect(history.document.toJson(), doc.toJson());
  });
  test('mixed picture/audio removal unions coincident gaps before removing indices', () {
    final doc = document(
      sceneAudio: [
        music(90, 0, 30),
        music(120, 30, 60, name: 'following'),
      ],
      picture: true,
    );
    final result = videoRippleDeleted(VideoLaneModel.build(document: doc), {
      'el:picture',
      'audio:s:0:0',
    }, document: doc)!.command!.apply(doc);
    expect(result.elementJson('picture'), isNull);
    expect(result.audioTracksJson(scene: 0).single['at'], {'kind': 'at', 'time': '90f'});
  });
  test('audio ripple out trim moves following material and retains cropped source', () {
    final doc = document(
      sceneAudio: [
        music(0, 60, 150),
        music(90, 0, 30, name: 'following'),
      ],
      picture: true,
    );
    final result = videoRippleTrimmed(
      VideoLaneModel.build(document: doc),
      'audio:s:0:0',
      0,
      60,
      document: doc,
    )!.command!.apply(doc);
    expect(result.audioTracksJson(scene: 0).first['trim'], {'from': '60f', 'to': '120f'});
    expect(result.audioTracksJson(scene: 0).last['at'], {'kind': 'at', 'time': '60f'});
    expect(result.elementJson('picture')!['show'], {'from': '60f', 'to': '90f'});
  });
  test('unknown trim, loops, and locked following rows refuse atomically', () {
    for (final patch in <Map<String, Object?>>[
      {'trim': null},
      {'loop': true},
    ]) {
      final track = {...music(0, 0, 90), ...patch}..removeWhere((_, value) => value == null);
      final doc = document(audio: [track]);
      final edit = audioBarRazored(
        VideoLaneModel.build(document: doc),
        'audio:v:0',
        30,
        document: doc,
      )!;
      expect(edit.command, isNull);
      expect(edit.note, isNotEmpty);
    }
    final doc = document(
      audio: [
        music(0, 0, 30),
        music(30, 30, 60, lane: 'locked'),
      ],
      locked: true,
    );
    final edit = videoRippleDeleted(VideoLaneModel.build(document: doc), {
      'audio:v:0',
    }, document: doc)!;
    expect(edit.command, isNull);
    expect(edit.note, contains('Unlock'));
  });
}
