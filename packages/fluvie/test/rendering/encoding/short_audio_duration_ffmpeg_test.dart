@Tags(['ffmpeg'])
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Quality;
import 'package:fluvie/src/audio/encoding/amix_node.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';

void main() {
  test('a short audio mix cannot truncate the authored video frame count', () async {
    final dir = await Directory.systemTemp.createTemp('fluvie_short_audio_');
    addTearDown(() => dir.delete(recursive: true));
    final source = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000:duration=3.5',
      'audio.wav',
    ], workingDirectory: dir.path);
    expect(source.exitCode, 0, reason: '${source.stderr}');
    final args = FfmpegArgsBuilder()
      ..addLavfiInput('color=red:s=32x32:r=12:d=4')
      ..setH264Output(
        name: 'out.mp4',
        quality: Quality.low,
        fps: 12,
        audio: [const AudioTrackNode(name: 'audio.wav')],
        amix: const AmixNode(inputCount: 1),
      );
    final encoded = await Process.run('ffmpeg', [
      '-v',
      'error',
      ...args.build(),
    ], workingDirectory: dir.path);
    expect(encoded.exitCode, 0, reason: '${encoded.stderr}');
    final probe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-count_frames',
      '-show_entries',
      'stream=nb_read_frames,duration',
      '-of',
      'json',
      'out.mp4',
    ], workingDirectory: dir.path);
    final stream = ((jsonDecode(probe.stdout as String) as Map)['streams'] as List).single as Map;
    expect(stream['nb_read_frames'], '48');
    expect(double.parse(stream['duration'] as String), closeTo(4, 0.001));
  });
}
