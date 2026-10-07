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
      // A retimed clip's audio must move with its picture, so the rate rides
      // the channel map; 1 leaves the stream alone.
      'tempo': 1.0,
    });
  });

  test('envelope and speed map survive the native channel without changing absent defaults', () {
    const resolved = ResolvedAudioTrack(
      source: 'clip.mp4',
      volumeEnvelope: [AudioVolumePoint(0, 1), AudioVolumePoint(1, 0.2)],
      endSeconds: 3,
      timeMap: AudioTimeMap(fps: 2, sourceSeconds: [0, 0.5, 1.5]),
    );
    final args = MobileAudioTrack.fromResolved(resolved, path: '/tmp/clip.mp4').toArguments();
    expect(args['volumeEnvelope'], [
      {'seconds': 0.0, 'value': 1.0},
      {'seconds': 1.0, 'value': 0.2},
    ]);
    expect(args['timeMap'], {
      'fps': 2,
      'sourceSeconds': [0.0, 0.5, 1.5],
    });
    expect(args['endSeconds'], 3);
  });

  test('a retimed track carries its rate to the native mixer', () {
    const resolved = ResolvedAudioTrack(source: 'clip.mp4', tempo: 0.5);

    final track = MobileAudioTrack.fromResolved(resolved, path: '/tmp/clip.mp4');

    expect(track.tempo, 0.5);
    expect(track.toArguments()['tempo'], 0.5);
  });
}
