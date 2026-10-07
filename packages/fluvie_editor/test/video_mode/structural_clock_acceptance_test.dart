import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show KeyframedNumber, audioVolumeAt, decodeAudioAutomation;
import 'package:fluvie/rendering.dart' show integrateClipSpeedRamp;
import 'package:fluvie_editor/fluvie_editor.dart';
import '../transitions/shared_clip_speed_test.dart' show sharedDeck;
import '../transitions/transition_edits_test.dart' show deck;
import 'video_audio_structure_test.dart' show music;

EditorDocument rippleDeck({bool locked = false, bool loop = false, bool full = false}) {
  final raw = sharedDeck().toJson();
  (raw['lanes']! as List<Object?>).add({'id': 'after', 'locked': locked});
  for (final (i, scene) in (raw['scenes']! as List<Object?>).cast<Map<String, Object?>>().indexed) {
    final children = scene['children']! as List<Object?>;
    (children.first! as Map<String, Object?>)['show'] = {'from': '0f', 'to': '30f'};
    children.add({
      'id': 'after$i',
      'type': 'Text',
      'text': 'Following',
      'lane': 'after',
      'show': {'from': '30f', 'to': full ? '110f' : '60f'},
    });
    scene['audio'] = [
      {...music(30, 0, 15), if (loop) 'loop': true},
    ];
  }
  return EditorDocument.fromJson(raw);
}

void main() {
  test(
    'shared ripple trims each source membership and shifts picture and audio by actual delta',
    () {
      final original = rippleDeck();
      final edit = videoRippleTrimmed(
        VideoLaneModel.build(document: original),
        'el:clip0',
        0,
        255,
        document: original,
      )!;
      expect(edit.command, isNotNull, reason: edit.note);
      final history = DocumentHistory(original)..dispatch(edit.command!);
      for (var i = 0; i < 3; i++) {
        expect(history.document.elementJson('clip$i')!['show'], {'from': '0f', 'to': '15f'});
        expect(history.document.elementJson('after$i')!['show'], {'from': '15f', 'to': '45f'});
        expect(history.document.audioTracksJson(scene: i).single['at'], {
          'kind': 'at',
          'time': '15f',
        });
        expect(history.document.spec.scenes[i].duration.toString(), contains('120'));
      }
      history.undo();
      expect(history.document.toJson(), original.toJson());
      expect(history.canUndo, isFalse);
      history.dispose();
    },
  );
  test(
    'shared ripple refuses locked followers, overflow and unresolved looping source atomically',
    () {
      for (final entry in [
        (rippleDeck(locked: true), 255, 'Unlock'),
        (rippleDeck(full: true), 300, 'outside'),
        (rippleDeck(loop: true), 255, 'loop'),
      ]) {
        final before = entry.$1.toJson();
        final edit = videoRippleTrimmed(
          VideoLaneModel.build(document: entry.$1),
          'el:clip0',
          0,
          entry.$2,
          document: entry.$1,
        )!;
        expect(edit.command, isNull);
        expect(edit.note!.toLowerCase(), contains(entry.$3.toLowerCase()));
        expect(entry.$1.toJson(), before);
      }
    },
  );
  test('shared move changes all scene-relative windows without changing local geometry', () {
    final original = rippleDeck();
    final edit = videoBarMoved(VideoLaneModel.build(document: original), 'el:clip0', 10)!;
    expect(edit.command, isNotNull, reason: edit.note);
    final changed = edit.command!.apply(original);
    for (var i = 0; i < 3; i++) {
      expect(changed.elementJson('clip$i')!['show'], {'from': '10f', 'to': '40f'});
      expect(
        changed.elementJson('clip$i')!['transform'],
        original.elementJson('clip$i')!['transform'],
      );
    }
  });
  test(
    'global clip razor preserves its home, exact source split and audio fade across both halves',
    () {
      final base = deck();
      final original = EditorDocument.fromJson({
        ...base.toJson(),
        'overlays': [
          {...base.elementJson('a')!, 'id': 'global', 'fadeIn': '2s', 'fadeOut': '2s'},
        ],
        'editor': const {
          'overlayHomes': {'global': 0},
        },
      });
      final edit = videoBarRazored(
        VideoLaneModel.build(document: original),
        'overlay:global',
        30,
        document: original,
      )!;
      expect(edit.command, isNotNull, reason: edit.note);
      final command = edit.command! as RazorElementCommand;
      final changed = command.apply(original);
      final head = changed.elementJson('global')!;
      final tail = changed.elementJson(command.tailId)!;
      expect(head['trim'], {'from': '1.0s', 'to': '2.0s'});
      expect(tail['trim'], {'from': '2.0s', 'to': '3.0s'});
      expect(changed.overlayHome(command.tailId), 0);
      expect(head.containsKey('fadeIn'), isFalse);
      expect(tail.containsKey('fadeOut'), isFalse);
      final a = decodeAudioAutomation(head['automation']).resolve(fps: 30, windowFrames: 30);
      final b = decodeAudioAutomation(tail['automation']).resolve(fps: 30, windowFrames: 30);
      for (var frame = 0; frame <= 60; frame++) {
        final actual = frame <= 30
            ? audioVolumeAt(a, frame / 30)
            : audioVolumeAt(b, (frame - 30) / 30);
        expect(actual, closeTo(frame / 60 * (60 - frame) / 60, 1e-10));
      }
    },
  );
  test('shared ramp razor retains source integral and curve phase for a cut between stops', () {
    final base = sharedDeck();
    final original = ReplaceElementCommand(
      id: 'clip0',
      element: {
        ...base.elementJson('clip0')!,
        'speed': const {
          'values': [1, 3],
          'positions': ['0r', '1r'],
        },
      },
    ).apply(base);
    final edit = videoBarRazored(
      VideoLaneModel.build(document: original),
      'el:clip0',
      150,
      document: original,
    )!;
    expect(edit.command, isNotNull, reason: edit.note);
    final command = edit.command! as SplitSharedChainCommand;
    final changed = command.apply(original);
    final head = changed.elementJson('clip1')!;
    final tail = changed.elementJson(command.tailPrimaryId)!;
    final originalRamp = KeyframedNumber.maybeFromJson(original.elementJson('clip1')!['speed'])!;
    final all = integrateClipSpeedRamp(originalRamp, fps: 30, windowFrames: 60);
    final tailMap = integrateClipSpeedRamp(
      KeyframedNumber.maybeFromJson(tail['speed'])!,
      fps: 30,
      windowFrames: 40,
    );
    for (var frame = 0; frame <= 40; frame++) {
      expect(tailMap[frame], closeTo(all[frame + 20] - all[20], 1e-10));
    }
    expect(
      (head['trim']! as Map<String, Object?>)['to'],
      (tail['trim']! as Map<String, Object?>)['from'],
    );
    expect(tail['transform'], original.elementJson('clip1')!['transform']);
  });
}
