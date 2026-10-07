import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';

void main() {
  test('absent automation preserves the exact legacy graph', () {
    expect(
      const AudioTrackNode(name: 'a.wav', volume: 0.5).filterChain(inputIndex: 1, label: 'a'),
      '[1:a]asetpts=PTS-STARTPTS,volume=0.5[a]',
    );
  });
  test('two stops compile one delayed expression with static gain folded in', () {
    const node = AudioTrackNode(
      name: 'a.wav',
      delayMs: 1000,
      volume: 0.5,
      volumeEnvelope: [AudioVolumePoint(0, 1), AudioVolumePoint(2, 0)],
    );
    expect(
      node.filterChain(inputIndex: 1, label: 'a'),
      "[1:a]asetpts=PTS-STARTPTS,adelay=1000|1000,asetpts=N/SR/TB,volume='if(lte((t-1),0),0.5,if(gte((t-1),2),0,0.5+-0.5*((t-1)-0)/2))':eval=frame[a]",
    );
  });
  test('one stop is constant; clamping happens before all encoders', () {
    final automation = decodeAudioAutomation({'volume': 2});
    expect(automation.resolve(fps: 30, windowFrames: 90).single.value, 1);
    expect(encodeAudioAutomation(automation), {'volume': 1.0});
    expect(
      const AudioTrackNode(
        name: 'a.wav',
        volumeEnvelope: [AudioVolumePoint(0, 0.2)],
      ).filterChain(inputIndex: 0, label: 'a'),
      "[0:a]asetpts=PTS-STARTPTS,volume='0.2':eval=frame[a]",
    );
  });
  test('V5 easing vocabulary resolves identically at every frame', () {
    final json = {
      'volume': {
        'values': [0.0, 1.0],
        'positions': ['0f', '30f'],
        'easings': ['smooth'],
      },
    };
    final automation = decodeAudioAutomation(json);
    final keyframes = KeyframedNumber.maybeFromJson(json['volume'])!;
    final points = automation.resolve(fps: 30, windowFrames: 30);
    for (var frame = 0; frame <= 30; frame++) {
      expect(
        audioVolumeAt(points, frame / 30),
        closeTo(keyframes.at((progress: frame / 30, fps: 30, windowFrames: 30)), 1e-8),
      );
    }
    expect(decodeAudioAutomation(encodeAudioAutomation(automation)), automation);
  });
  test('unordered stops and nonfinite values are refused', () {
    expect(
      () => decodeAudioAutomation({
        'volume': {
          'values': [0, 1],
          'positions': ['2s', '1s'],
        },
      }),
      throwsA(isA<FluvieSpecError>()),
    );
    expect(() => decodeAudioAutomation({'volume': double.nan}), throwsA(isA<FluvieSpecError>()));
    expect(
      () => const AudioTrackNode(
        name: 'a.wav',
        volumeEnvelope: [AudioVolumePoint(1, 1), AudioVolumePoint(0, 0)],
      ).filterChain(inputIndex: 0, label: 'a'),
      throwsArgumentError,
    );
  });
  test('lane gain and mute apply to scene tracks in declaration order', () {
    final spec = VideoSpec.fromJson({
      'fluvieSpec': 1,
      'fps': 30,
      'size': {'width': 320, 'height': 180},
      'lanes': [
        {'id': 'quiet', 'kind': 'audio', 'muted': true},
        {'id': 'bed', 'kind': 'audio', 'gain': 0.5},
      ],
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'first.wav'},
          'lane': 'bed',
        },
      ],
      'scenes': [
        {'duration': '2s'},
        {
          'duration': '3s',
          'audio': [
            {
              'kind': 'music',
              'source': {'kind': 'asset', 'value': 'muted.wav'},
              'lane': 'quiet',
            },
            {
              'kind': 'music',
              'source': {'kind': 'asset', 'value': 'last.wav'},
              'lane': 'bed',
              'automation': {
                'volume': {
                  'values': [1, 0],
                  'positions': ['0r', '1r'],
                },
              },
            },
          ],
        },
      ],
    });
    final video = spec.build();
    expect(collectAudioTracks(video).map((a) => a.source), ['first.wav', 'last.wav']);
    final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 150);
    expect(mix.tracks.map((a) => a.volume), [0.5, 0.5]);
    expect(mix.tracks.last.delayMs, 2000);
    expect(mix.tracks.last.endSeconds, 5);
    expect(mix.tracks.last.volumeEnvelope.last.seconds, 3);
    expect(VideoSpec.fromJson(spec.toJson()).digest(), spec.digest());
  });
  test('clip automation reaches the encoder-neutral mix', () {
    final video = VideoSpec.fromJson({
      'fluvieSpec': 1,
      'fps': 30,
      'size': {'width': 320, 'height': 180},
      'scenes': [
        {
          'duration': '3s',
          'children': [
            {
              'type': 'Clip',
              'source': {'kind': 'asset', 'value': 'clip.mp4'},
              'automation': {'volume': 0.25},
            },
          ],
        },
      ],
    }).build();
    final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 90);
    expect(mix.tracks.single.volumeEnvelope.single.value, 0.25);
    expect(
      AudioTrackNode.fromResolved(
        mix.tracks.single,
        name: 'a',
      ).filterChain(inputIndex: 0, label: 'a'),
      contains("volume='0.25':eval=frame"),
    );
  });
}
