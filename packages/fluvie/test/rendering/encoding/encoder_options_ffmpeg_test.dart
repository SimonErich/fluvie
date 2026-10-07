@Tags(['ffmpeg'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';

void main() {
  for (final codec in ExportCodec.values) {
    test('real FFmpeg encodes ${codec.name} with typed delivery knobs', () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_delivery_');
      addTearDown(() => directory.delete(recursive: true));
      final args =
          (FfmpegArgsBuilder()
                ..addLavfiInput('color=c=blue:s=64x64:r=10:d=0.3')
                ..setH264Output(
                  name: 'out.mp4',
                  quality: Quality.high,
                  fps: 10,
                  codec: codec,
                  preset: EncoderPreset.ultrafast,
                  bitRate: 250000,
                  pixelFormat: codec == ExportCodec.h264
                      ? ExportPixelFormat.yuv420p
                      : ExportPixelFormat.yuv420p10le,
                ))
              .build();
      final encoded = await Process.run('ffmpeg', [
        '-v',
        'error',
        ...args,
      ], workingDirectory: directory.path);
      expect(encoded.exitCode, 0, reason: '${encoded.stderr}');
      final probed = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_streams',
        '-of',
        'json',
        'out.mp4',
      ], workingDirectory: directory.path);
      expect(probed.exitCode, 0, reason: '${probed.stderr}');
      final streams = (jsonDecode(probed.stdout as String) as Map)['streams'] as List;
      expect((streams.single as Map)['codec_name'], codec == ExportCodec.h264 ? 'h264' : 'hevc');
      expect(
        (streams.single as Map)['pix_fmt'],
        codec == ExportCodec.h264 ? 'yuv420p' : 'yuv420p10le',
      );
    });
  }
}
