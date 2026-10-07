import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/encoding/video_encoder_service.dart';
import 'package:fluvie/src/serialization/codecs/export_codec.dart';

void main() {
  final config = RenderConfig(width: 320, height: 180, frameCount: 90);
  const encoder = VideoEncoderService();
  String argument(List<String> args, String key) => args[args.lastIndexOf(key) + 1];
  test('absent knobs keep the exact original argument list', () {
    expect(
      encoder.planEncodeArgs(config, export: const Export.mp4()),
      encoder.planEncodeArgs(config),
    );
    expect(encodeExport(const Export.mp4()), {'mode': 'mp4', 'quality': 'high'});
  });
  test('codec, CRF, preset and pixel format are typed arguments', () {
    final args = encoder.planEncodeArgs(
      config,
      export: const Export.mp4(
        codec: ExportCodec.h265,
        crf: 21,
        preset: EncoderPreset.slow,
        pixelFormat: ExportPixelFormat.yuv420p10le,
      ),
    );
    expect(argument(args, '-c:v'), 'libx265');
    expect(argument(args, '-crf'), '21');
    expect(argument(args, '-preset'), 'slow');
    expect(argument(args, '-pix_fmt'), 'yuv420p10le');
    expect(args, isNot(contains('-b:v')));
  });
  test('target bitrate replaces CRF and works with PNG input on web', () {
    final args = encoder.planEncodeArgs(
      config,
      framesArePng: true,
      export: const Export.mp4(bitRate: 5000000, preset: EncoderPreset.fast),
    );
    expect(argument(args, '-b:v'), '5000000');
    expect(args, isNot(contains('-crf')));
    expect(args, contains('frame_%06d.png'));
  });
  test('every closed encoder enum maps to a deterministic literal', () {
    for (final preset in EncoderPreset.values) {
      expect(
        argument(encoder.planEncodeArgs(config, export: Export.mp4(preset: preset)), '-preset'),
        preset.name,
      );
    }
    for (final pixel in ExportPixelFormat.values) {
      expect(
        argument(
          encoder.planEncodeArgs(config, export: Export.mp4(pixelFormat: pixel)),
          '-pix_fmt',
        ),
        pixel.name,
      );
    }
  });
  test('invalid encoder config is rejected before rendering', () {
    for (final bad in <Map<String, Object?>>[
      {'codec': 'custom -i evil'},
      {'preset': 'unknown'},
      {'pixelFormat': 'rgba'},
      {'crf': -1},
      {'crf': 52},
      {'crf': 2.5},
      {'bitRate': 0},
      {'bitRate': -1},
      {'bitRate': 2.5},
      {'crf': 18, 'bitRate': 5000000},
      {'surprise': true},
    ]) {
      expect(
        () => decodeExport({'mode': 'mp4', ...bad}),
        throwsA(isA<FluvieSpecError>()),
        reason: '$bad',
      );
    }
  });
  test('advanced export corpus roundtrips and pins digest', () {
    final spec = VideoSpec.fromJson(
      jsonDecode(File('test/serialization/corpus/encoder_options.fluvie.json').readAsStringSync())
          as Map<String, Object?>,
    );
    expect(VideoSpec.fromJson(spec.toJson()).digest(), spec.digest());
    expect(spec.digest(), 'ac338d89644cd5f6');
  });
}
