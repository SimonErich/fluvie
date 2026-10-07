import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show FrameSpan;
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({bool videoAudio = true, bool sceneAudio = true}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  if (videoAudio)
    'audio': [
      {
        'kind': 'music',
        'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
      },
      {
        'kind': 'sfx',
        'source': {'kind': 'asset', 'value': 'audio/whoosh.wav'},
      },
    ],
  'scenes': <Object?>[
    <String, Object?>{
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    <String, Object?>{
      'duration': '90f',
      if (sceneAudio)
        'audio': [
          {
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'audio/voice.mp3'},
            'volume': 0.8,
          },
        ],
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
      ],
    },
  ],
};

void main() {
  group('EditorDocumentAudio', () {
    test('reads the audio lists at both levels, empty when absent', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.audioTracksJson(), hasLength(2));
      expect(document.audioTracksJson().first['kind'], 'music');
      expect(document.audioTracksJson(scene: 1), hasLength(1));
      expect(document.audioTracksJson(scene: 1).first['volume'], 0.8);
      expect(document.audioTracksJson(scene: 0), isEmpty);
      final bare = EditorDocument.fromJson(_deck(videoAudio: false, sceneAudio: false));
      expect(bare.audioTracksJson(), isEmpty);
      expect(bare.audioTracksJson(scene: 1), isEmpty);
    });

    test('addAudioTrack appends, creating the list when absent', () {
      final bare = EditorDocument.fromJson(_deck(videoAudio: false, sceneAudio: false));
      final track = {
        'kind': 'music',
        'source': {'kind': 'asset', 'value': 'audio/new.mp3'},
      };
      final withVideo = bare.addAudioTrack(track: track);
      expect(withVideo.audioTracksJson(), [track]);
      final withScene = withVideo.addAudioTrack(scene: 0, track: track);
      expect(withScene.audioTracksJson(scene: 0), [track]);
      // The originals stayed untouched (immutability law).
      expect(bare.audioTracksJson(), isEmpty);
    });

    test('updateAudioTrack merges a patch and a null value removes its key', () {
      final document = EditorDocument.fromJson(_deck());
      final updated = document.updateAudioTrack(
        index: 0,
        patch: {
          'volume': 0.5,
          'trim': {'from': '0f', 'to': '60f'},
        },
      );
      expect(updated.audioTracksJson().first['volume'], 0.5);
      expect(updated.audioTracksJson().first['trim'], {'from': '0f', 'to': '60f'});
      final cleared = updated.updateAudioTrack(index: 0, patch: {'volume': null, 'trim': null});
      expect(cleared.audioTracksJson().first.containsKey('volume'), isFalse);
      expect(cleared.audioTracksJson().first.containsKey('trim'), isFalse);
    });

    test('updateAudioTrack places music without losing its source or mix', () {
      final document = EditorDocument.fromJson(_deck());
      final updated = document.updateAudioTrack(
        index: 0,
        patch: const {
          'at': {'kind': 'at', 'time': '10f'},
          'trim': {'from': '5f', 'to': '35f'},
          'volume': 0.5,
        },
      );
      final restored = EditorDocument.fromJson(updated.toJson());
      expect(restored.renderDigest, updated.renderDigest);
      expect(restored.audioTracksJson().first['at'], {'kind': 'at', 'time': '10f'});
      final model = VideoLaneModel.build(document: restored);
      expect(model.audioBars['audio:v:0']!.span, const FrameSpan(10, 40));
      expect(restored.spec.audio.first.volume, 0.5);
      expect(
        restored.audioTracksJson().first['source'],
        document.audioTracksJson().first['source'],
      );
    });

    test('removeAudioTrack removes, and the emptied list drops the audio key', () {
      final document = EditorDocument.fromJson(_deck());
      final one = document.removeAudioTrack(index: 1);
      expect(one.audioTracksJson(), hasLength(1));
      final none = one.removeAudioTrack(index: 0);
      expect(none.audioTracksJson(), isEmpty);
      expect(none.toJson().containsKey('audio'), isFalse);
      final scene = document.removeAudioTrack(scene: 1, index: 0);
      expect(scene.sceneJson(1).containsKey('audio'), isFalse);
    });

    test('reorderAudioTrack moves an entry within its list', () {
      final document = EditorDocument.fromJson(_deck());
      final swapped = document.reorderAudioTrack(from: 0, to: 1);
      expect(swapped.audioTracksJson().first['kind'], 'sfx');
      expect(swapped.audioTracksJson().last['kind'], 'music');
    });

    test('index errors name the problem', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.updateAudioTrack(index: 9, patch: const {}), throwsRangeError);
      expect(() => document.removeAudioTrack(scene: 1, index: 2), throwsRangeError);
      expect(() => document.reorderAudioTrack(from: 5, to: 0), throwsRangeError);
    });
  });

  group('audio commands', () {
    test('AddAudioTrackCommand appends and undoes back', () {
      final history =
          DocumentHistory(EditorDocument.fromJson(_deck(videoAudio: false, sceneAudio: false)))
            ..dispatch(
              const AddAudioTrackCommand(
                track: {
                  'kind': 'music',
                  'source': {'kind': 'asset', 'value': 'audio/new.mp3'},
                },
              ),
            );
      expect(history.document.audioTracksJson(), hasLength(1));
      history.undo();
      expect(history.document.audioTracksJson(), isEmpty);
      expect(history.document.toJson().containsKey('audio'), isFalse);
    });

    test('SetAudioTrackCommand patches one track and undoes back', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const SetAudioTrackCommand(scene: 1, index: 0, patch: {'volume': 0.25}));
      expect(history.document.audioTracksJson(scene: 1).first['volume'], 0.25);
      history.undo();
      expect(history.document.audioTracksJson(scene: 1).first['volume'], 0.8);
    });

    test('SetAudioTrackCommand coalesces a drag through its merge group', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(
          const SetAudioTrackCommand(
            index: 0,
            patch: {
              'trim': {'from': '0f', 'to': '40f'},
            },
            mergeGroup: 'drag-1',
          ),
        )
        ..dispatch(
          const SetAudioTrackCommand(
            index: 0,
            patch: {
              'trim': {'from': '0f', 'to': '55f'},
            },
            mergeGroup: 'drag-1',
          ),
        );
      expect(history.document.audioTracksJson().first['trim'], {'from': '0f', 'to': '55f'});
      history.undo();
      expect(history.document.audioTracksJson().first.containsKey('trim'), isFalse);
      expect(history.canUndo, isFalse);
    });

    test('a standalone SetAudioTrackCommand never merges', () {
      expect(const SetAudioTrackCommand(index: 0, patch: {'volume': 1}).mergeKey, isNull);
      expect(
        const SetAudioTrackCommand(index: 0, patch: {'volume': 1}, mergeGroup: 'g').mergeKey,
        isNot(
          const SetAudioTrackCommand(
            scene: 2,
            index: 0,
            patch: {'volume': 1},
            mergeGroup: 'g',
          ).mergeKey,
        ),
      );
    });

    test('RemoveAudioTrackCommand removes and undoes back', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const RemoveAudioTrackCommand(index: 0));
      expect(history.document.audioTracksJson(), hasLength(1));
      history.undo();
      expect(history.document.audioTracksJson(), hasLength(2));
    });

    test('ReorderAudioTrackCommand moves and undoes back', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const ReorderAudioTrackCommand(from: 0, to: 1));
      expect(history.document.audioTracksJson().first['kind'], 'sfx');
      history.undo();
      expect(history.document.audioTracksJson().first['kind'], 'music');
    });

    test('the commands carry honest labels and touch no elements', () {
      const add = AddAudioTrackCommand(track: {});
      const set = SetAudioTrackCommand(index: 0, patch: {});
      const remove = RemoveAudioTrackCommand(index: 0);
      const reorder = ReorderAudioTrackCommand(from: 0, to: 1);
      expect(add.label, 'Add audio track');
      expect(set.label, 'Edit audio track');
      expect(remove.label, 'Remove audio track');
      expect(reorder.label, 'Reorder audio tracks');
      for (final command in [add, set, remove, reorder]) {
        expect(command.affectedIds, isEmpty);
      }
    });
  });
}
