@Tags(['ffmpeg'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import '../../serialization/element_transition_spec_test.dart' show deck;

void main() {
  test('real encoder evaluates both clip crossfade envelopes on the picture window', () async {
    final video = VideoSpec.fromJson(deck()).build();
    final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 120);
    final directory = await Directory.systemTemp.createTemp('fluvie_crossfade_');
    addTearDown(() => directory.delete(recursive: true));
    final chains = <String>[];
    for (var i = 0; i < mix.tracks.length; i++) {
      final track = mix.tracks[i];
      chains.add(
        AudioTrackNode(
          name: track.source,
          delayMs: track.delayMs,
          volume: track.volume,
          volumeEnvelope: track.volumeEnvelope,
          trimStartSeconds: track.trimStartSeconds,
          trimEndSeconds: track.trimEndSeconds,
          tempo: track.tempo,
        ).filterChain(inputIndex: i, label: 'clip$i'),
      );
    }
    expect(chains[0], contains("volume='"));
    expect(chains[1], contains('adelay=1667|1667'));
    chains.add('[clip0][clip1]join=inputs=2:channel_layout=stereo[out]');
    final result = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'aevalsrc=0.1:s=48000:d=2',
      '-f',
      'lavfi',
      '-i',
      'aevalsrc=0.1:s=48000:d=2',
      '-filter_complex',
      chains.join(';'),
      '-map',
      '[out]',
      '-f',
      'f32le',
      'out.pcm',
    ], workingDirectory: directory.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final bytes = ByteData.sublistView(await File('${directory.path}/out.pcm').readAsBytes());
    double channel(double seconds, int channel) =>
        bytes.getFloat32(((seconds * 48000).round() * 2 + channel) * 4, Endian.little);
    expect(channel(1.6, 0), closeTo(0.1, 1e-5));
    expect(channel(1.6, 1), 0);
    for (final seconds in [1.72, 1.80, 1.88, 1.95]) {
      final a = channel(seconds, 0);
      final b = channel(seconds, 1);
      expect(a * a + b * b, closeTo(0.01, 0.0015));
      expect(a, inInclusiveRange(0, 0.1));
      expect(b, inInclusiveRange(0, 0.1));
    }
  });
}
