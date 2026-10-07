@Tags(['ffmpeg'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';

void main() {
  test('real FFmpeg evaluates delayed automation and preserves absent output', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_envelope_');
    addTearDown(() => directory.delete(recursive: true));
    const node = AudioTrackNode(
      name: 'source.wav',
      delayMs: 500,
      volumeEnvelope: [
        AudioVolumePoint(0, 1),
        AudioVolumePoint(0.5, 1),
        AudioVolumePoint(0.6, 0.1),
        AudioVolumePoint(1.4, 0.1),
        AudioVolumePoint(1.5, 1),
        AudioVolumePoint(2, 1),
      ],
    );
    final graph = node.filterChain(inputIndex: 0, label: 'out');
    final result = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000:duration=2',
      '-filter_complex',
      graph,
      '-map',
      '[out]',
      '-f',
      'f32le',
      'out.pcm',
    ], workingDirectory: directory.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final bytes = await File('${directory.path}/out.pcm').readAsBytes();
    final data = ByteData.sublistView(bytes);
    double peak(double start, double end) {
      var value = 0.0;
      for (var i = (start * 48000).round(); i < (end * 48000).round(); i++) {
        final sample = data.getFloat32(i * 4, Endian.little).abs();
        if (sample > value) value = sample;
      }
      return value;
    }

    expect(peak(0, 0.4), 0);
    final loud = peak(0.6, 0.9);
    final ducked = peak(1.2, 1.7);
    final recovered = peak(2.1, 2.4);
    expect(loud, greaterThan(0.1));
    expect(ducked / loud, closeTo(0.1, 0.005));
    expect(recovered / loud, closeTo(1, 0.005));
  });
}
