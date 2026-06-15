@Tags(['ffmpeg'])
library;

// Live acceptance for the §24 export modes (WI-20, §14.5.3): encodes each mode
// with the real ffmpeg binary and ffprobe-verifies the artifact. Needs
// ffmpeg >= 6.0 (with libvpx-vp9) AND ffprobe on PATH; gated by the ffmpeg tag.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/rendering/encoding/video_encoder_service.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/render_config.dart';

const _width = 320;
const _height = 240;
const _frameCount = 30;
const int _frameBytes = _width * _height * 4;

RenderConfig _config() => RenderConfig(width: _width, height: _height, frameCount: _frameCount);

/// One synthetic gradient frame with a sweeping alpha gradient so the
/// transparent encode has a real alpha plane to preserve.
Uint8List _gradientFrame(int frame) {
  final bytes = Uint8List(_frameBytes);
  var offset = 0;
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      bytes[offset++] = (x * 255) ~/ (_width - 1);
      bytes[offset++] = (y * 255) ~/ (_height - 1);
      bytes[offset++] = (frame * 8) % 256;
      bytes[offset++] = (x * 255) ~/ (_width - 1);
    }
  }
  return bytes;
}

Future<Directory> _sandboxWithFrames() async {
  final sandbox = await Directory.systemTemp.createTemp('fluvie_export_test_');
  addTearDown(() => sandbox.delete(recursive: true));
  final sink = File('${sandbox.path}/frames.rgba').openWrite();
  for (var frame = 0; frame < _frameCount; frame++) {
    sink.add(_gradientFrame(frame));
  }
  await sink.close();
  return sandbox;
}

Future<Map<String, Object?>> _ffprobe(Directory sandbox, String file) async {
  final result = await Process.run('ffprobe', [
    '-v',
    'error',
    '-print_format',
    'json',
    '-show_streams',
    '-show_format',
    file,
  ], workingDirectory: sandbox.path);
  expect(result.exitCode, 0, reason: 'ffprobe failed: ${result.stderr}');
  return jsonDecode(result.stdout as String) as Map<String, Object?>;
}

void main() {
  const service = VideoEncoderService();

  setUpAll(() async {
    const hint = 'The ffmpeg-tagged suite needs ffmpeg >= 6.0 AND ffprobe on PATH.';
    try {
      final version = await ProcessFfmpegProvider().probeVersion();
      expect(version!.meetsFloor, isTrue, reason: 'found ffmpeg $version. $hint');
    } on FluvieEncodeException catch (error) {
      fail('$error\n$hint');
    }
    final ffprobe = await Process.run('ffprobe', const ['-version']);
    expect(ffprobe.exitCode, 0, reason: hint);
  });

  test('Export.gif() produces a real gif', () async {
    final sandbox = await _sandboxWithFrames();
    await service.encode(
      config: _config(),
      sandbox: sandbox,
      provider: ProcessFfmpegProvider(),
      export: const Export.gif(),
    );
    final output = File('${sandbox.path}/out.gif');
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(0));
    final probe = await _ffprobe(sandbox, 'out.gif');
    final stream = (probe['streams']! as List<Object?>).first! as Map<String, Object?>;
    expect(stream['codec_name'], 'gif');
  });

  test('Export.transparent() produces a webm with a yuva420p alpha plane', () async {
    final sandbox = await _sandboxWithFrames();
    await service.encode(
      config: _config(),
      sandbox: sandbox,
      provider: ProcessFfmpegProvider(),
      export: const Export.transparent(),
    );
    final output = File('${sandbox.path}/out.webm');
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(0));
    final probe = await _ffprobe(sandbox, 'out.webm');
    final stream = (probe['streams']! as List<Object?>).first! as Map<String, Object?>;
    expect(stream['codec_name'], 'vp9');
    // VP9-in-WebM carries alpha as a separate coded layer flagged by the
    // `alpha_mode` stream tag, so ffprobe reports the base pix_fmt as yuv420p
    // while alpha_mode=1 proves the alpha plane survived (decision
    // D-Export-Dispatch: we request yuva420p, never force yuv420p).
    final tags = stream['tags']! as Map<String, Object?>;
    expect(tags['alpha_mode'], '1', reason: 'the alpha plane must survive');
  });

  test('Export.imageSequence() writes one png per frame', () async {
    final sandbox = await _sandboxWithFrames();
    await service.encode(
      config: _config(),
      sandbox: sandbox,
      provider: ProcessFfmpegProvider(),
      export: const Export.imageSequence(),
    );
    final pngs = sandbox.listSync().whereType<File>().where((f) => f.path.endsWith('.png'));
    expect(pngs, hasLength(_frameCount));
  });

  test('the poster invocation extracts a single PNG that exists', () async {
    final sandbox = await _sandboxWithFrames();
    await ProcessFfmpegProvider().encode(
      args: service.planPosterArgs(_config(), posterFrame: 10),
      sandbox: sandbox,
    );
    final poster = File('${sandbox.path}/${VideoEncoderService.posterFileName}');
    expect(poster.existsSync(), isTrue);
    final probe = await _ffprobe(sandbox, VideoEncoderService.posterFileName);
    final stream = (probe['streams']! as List<Object?>).first! as Map<String, Object?>;
    expect(stream['codec_name'], 'png');
    expect(stream['width'], _width);
    expect(stream['height'], _height);
  });
}
