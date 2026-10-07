import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';

void main() {
  test('trimmed music placement roundtrips and resolves owner-relative delay/fades', () {
    final spec = VideoSpec.fromJson({
      'fluvieSpec': 1,
      'fps': 10,
      'size': {'width': 100, 'height': 100},
      'scenes': [
        {'duration': '10s'},
      ],
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'voice.wav'},
          'at': {'kind': 'at', 'time': '3s'},
          'trim': {'from': '2s', 'to': '5s'},
          'fadeOut': '1s',
        },
      ],
    });
    final roundtrip = VideoSpec.fromJson(spec.toJson());
    expect(roundtrip.digest(), spec.digest());
    final track = resolveAudioMix(
      video: roundtrip.build(),
      fps: 10,
      totalFrames: 100,
    ).tracks.single;
    expect(track.delayMs, 3000);
    expect(track.trimStartSeconds, 2);
    expect(track.trimEndSeconds, 5);
    expect(track.fadeOutStartSeconds, 5);
    expect(
      AudioTrackNode.fromResolved(
        track,
        name: 'voice.wav',
      ).filterChain(inputIndex: 1, label: 'mix'),
      contains('adelay=3000|3000'),
    );
  });
}
