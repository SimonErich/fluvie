@Tags(['ffmpeg'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';

void main() {
  test('real FFmpeg follows source-clock tempo ramp before delay and automation', () async {
    final directory = Directory.systemTemp.createTempSync('fluvie_ramp_audio_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final map = AudioTimeMap(
      fps: 30,
      sourceSeconds: [
        for (var frame = 0; frame <= 60; frame++) frame / 30 + (frame / 30) * (frame / 30) / 4,
      ],
    );
    final node = AudioTrackNode(
      name: 'tone.wav',
      delayMs: 500,
      timeMap: map,
      trimStartSeconds: 0,
      trimEndSeconds: 3,
      volumeEnvelope: const [AudioVolumePoint(0, 0.5)],
    );
    final result = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      "aevalsrc='if(lt(t,1),0.1,0.8)':s=48000:d=3",
      '-filter_complex',
      node.filterChain(inputIndex: 0, label: 'out'),
      '-map',
      '[out]',
      '-f',
      'f32le',
      'out.pcm',
    ], workingDirectory: directory.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final bytes = File('${directory.path}/out.pcm').readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    double sample(double seconds) => data.getFloat32((seconds * 48000).round() * 4, Endian.little);
    expect(bytes.length / 4 / 48000, closeTo(2.5, 1 / 48000));
    expect(sample(0.2), 0);
    expect(sample(0.9), closeTo(0.05, 0.002));
    expect(sample(1.7), closeTo(0.4, 0.002));
    var crossing = 0.0;
    for (var i = 24000; i < bytes.length ~/ 4; i++) {
      if (data.getFloat32(i * 4, Endian.little) > 0.225) {
        crossing = i / 48000 - 0.5;
        break;
      }
    }
    // Integrated source second1 falls at output sqrt(8)-2≈0.828s.
    expect(crossing, closeTo(0.828427, 0.06));
  });
}
