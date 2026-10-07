import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  EditorDocument fixture() => EditorDocument.fromJson(const {
    'fluvieSpec': 1,
    'fps': 10,
    'size': {'width': 100, 'height': 100},
    'lanes': [
      {'id': 'voice', 'kind': 'video', 'gain': 2},
    ],
    'scenes': [
      {
        'duration': '4s',
        'children': [
          {
            'id': 'clip',
            'type': 'Clip',
            'lane': 'voice',
            'source': {'kind': 'asset', 'value': 'voice.mp4'},
            'show': {'from': '1s', 'to': '3s'},
            'trim': {'from': '1s', 'to': '5s'},
            'speed': 2,
            'volume': 0.5,
            'automation': {
              'volume': {
                'values': [0, 1],
                'positions': ['0f', '20f'],
              },
            },
          },
        ],
      },
    ],
  });
  const metadata = <String, ClipMetadata>{
    'voice.mp4': (fps: 10, frameCount: 100, width: 100, height: 100, hasAudio: true),
  };
  test('embedded clip uses resolved trim, tempo, lane gain, and timeline envelope', () {
    final document = fixture();
    final track = audioTrackViews(
      document,
      VideoTimebase.of(document),
      clipMetadata: metadata,
    ).single;
    expect(track.elementId, 'clip');
    expect(track.span.start, 10);
    expect(track.span.end, 30);
    expect(track.resolved.delayMs, 1000);
    expect(track.resolved.volume, 1);
    expect(track.resolved.tempo, 2);
    expect(track.resolved.trimStartSeconds, 1);
    expect(track.resolved.trimEndSeconds, 5);
    expect(audioVolumeAt(track.resolved.volumeEnvelope, 1), 0.5);
    expect(document.elementJson('clip')!['volume'], 0.5);
    final muted = document.updateLane('voice', {'muted': true});
    expect(
      audioTrackViews(
        muted,
        VideoTimebase.of(muted),
        clipMetadata: metadata,
      ).single.resolved.volume,
      0,
    );
  });
  test('missing trim metadata is visible and never plays an invented source range', () {
    final document = fixture();
    final track = audioTrackViews(document, VideoTimebase.of(document)).single;
    expect(track.unavailableReason, contains('metadata'));
    expect(track.resolved.volume, 0);
  });
  test('clip ducking and clear are single reversible commands', () {
    final history = DocumentHistory(fixture());
    addTearDown(history.dispose);
    final before = history.document.documentDigest;
    history.dispatch(
      const DuckAudioTracksCommand(
        envelopes: [],
        clipEnvelopes: {
          'clip': {'volume': 0.2},
        },
      ),
    );
    expect(history.document.elementJson('clip')!['automation'], {'volume': 0.2});
    history.undo();
    expect(history.document.documentDigest, before);
    history.dispatch(const DuckAudioTracksCommand(envelopes: [], clipEnvelopes: {'clip': {}}));
    expect(history.document.elementJson('clip')!.containsKey('automation'), isFalse);
    history.undo();
    expect(history.document.documentDigest, before);
  });
}
