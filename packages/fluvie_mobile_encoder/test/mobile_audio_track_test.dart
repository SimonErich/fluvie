import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  test('builds from a resolved track and serializes to the channel map', () {
    const resolved = ResolvedAudioTrack(
      source: 'audio/song.mp3',
      delayMs: 250,
      volume: 0.7,
      trimStartSeconds: 1,
      trimEndSeconds: 4,
      fadeInSeconds: 0.5,
      fadeOutSeconds: 1,
      fadeOutStartSeconds: 3,
      loop: true,
    );

    final track = MobileAudioTrack.fromResolved(resolved, path: '/tmp/song.bin');

    expect(track.path, '/tmp/song.bin');
    expect(track.delayMs, 250);
    expect(track.volume, 0.7);
    expect(track.loop, isTrue);
    expect(track.toArguments(), {
      'path': '/tmp/song.bin',
      'delayMs': 250,
      'volume': 0.7,
      'trimStartSeconds': 1.0,
      'trimEndSeconds': 4.0,
      'fadeInSeconds': 0.5,
      'fadeOutSeconds': 1.0,
      'fadeOutStartSeconds': 3.0,
      'loop': true,
    });
  });
}
