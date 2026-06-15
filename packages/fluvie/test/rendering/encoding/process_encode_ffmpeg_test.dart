@Tags(['ffmpeg'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_filter_graph_builder.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_provider.dart';

const _width = 320;
const _height = 240;
const _fps = 30;
const _frameCount = 30;
const int _frameBytes = _width * _height * 4;

/// One synthetic gradient frame — pure integer math on (x, y, frame).
Uint8List _gradientFrame(int frame) {
  final bytes = Uint8List(_frameBytes);
  var offset = 0;
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      bytes[offset++] = (x * 255) ~/ (_width - 1);
      bytes[offset++] = (y * 255) ~/ (_height - 1);
      bytes[offset++] = (frame * 8) % 256;
      bytes[offset++] = 255;
    }
  }
  return bytes;
}

Future<Directory> _newSandbox() async {
  final sandbox = await Directory.systemTemp.createTemp('fluvie_ffmpeg_test_');
  addTearDown(() => sandbox.delete(recursive: true));
  return sandbox;
}

Future<void> _writeFrames(Directory sandbox) async {
  final sink = File('${sandbox.path}/frames.rgba').openWrite();
  for (var frame = 0; frame < _frameCount; frame++) {
    sink.add(_gradientFrame(frame));
  }
  await sink.close();
}

List<String> _encodeArgs() {
  final filters = const FfmpegFilterGraphBuilder().forFrames(width: _width, height: _height);
  return (FfmpegArgsBuilder()
        ..addRawVideoInput(name: 'frames.rgba', width: _width, height: _height, fps: _fps)
        ..setH264Output(name: 'out.mp4', quality: Quality.high, fps: _fps, filters: filters))
      .build();
}

Future<File> _encode(Directory sandbox) async {
  await _writeFrames(sandbox);
  await ProcessFfmpegProvider().encode(args: _encodeArgs(), sandbox: sandbox);
  return File('${sandbox.path}/out.mp4');
}

/// Probes `out.mp4` with a raw argument-array ffprobe invocation.
Future<Map<String, Object?>> _ffprobe(Directory sandbox) async {
  final result = await Process.run('ffprobe', const [
    '-v',
    'error',
    '-print_format',
    'json',
    '-show_streams',
    '-show_format',
    'out.mp4',
  ], workingDirectory: sandbox.path);
  expect(result.exitCode, 0, reason: 'ffprobe failed: ${result.stderr}');
  return jsonDecode(result.stdout as String) as Map<String, Object?>;
}

/// Decodes `out.mp4` back to raw RGBA and returns one FNV-1a-64 hash per frame.
Future<List<int>> _decodedFrameHashes(Directory sandbox) async {
  final result = await Process.run('ffmpeg', const [
    '-v',
    'error',
    '-i',
    'out.mp4',
    '-f',
    'rawvideo',
    '-pix_fmt',
    'rgba',
    'decoded.rgba',
  ], workingDirectory: sandbox.path);
  expect(result.exitCode, 0, reason: 'decode-back failed: ${result.stderr}');
  final decoded = await File('${sandbox.path}/decoded.rgba').readAsBytes();
  expect(decoded.length, _frameCount * _frameBytes, reason: 'decoded stream has wrong length');
  return [
    for (var frame = 0; frame < _frameCount; frame++)
      _fnv1a64(decoded, frame * _frameBytes, (frame + 1) * _frameBytes),
  ];
}

int _fnv1a64(Uint8List bytes, int start, int end) {
  // FNV-1a-64 offset basis, split so the literal stays JS-representable.
  var hash = (0xcbf29ce4 << 32) | 0x84222325;
  for (var i = start; i < end; i++) {
    hash = (hash ^ bytes[i]) * 0x100000001b3;
  }
  return hash;
}

void main() {
  setUpAll(() async {
    const hint =
        'The ffmpeg-tagged suite needs ffmpeg >= 6.0 AND ffprobe on PATH '
        '(e.g. `sudo apt install ffmpeg`), or FLUVIE_FFMPEG pointing at a binary.';
    try {
      final version = await ProcessFfmpegProvider().probeVersion();
      expect(version!.meetsFloor, isTrue, reason: 'found ffmpeg $version. $hint');
    } on FluvieEncodeException catch (error) {
      fail('$error\n$hint');
    }
    final ffprobe = await Process.run('ffprobe', const ['-version']);
    expect(ffprobe.exitCode, 0, reason: hint);
  });

  group('ProcessFfmpegProvider against the real binary', () {
    test('encodes 30 synthetic gradient frames to an mp4 that exists and is non-empty', () async {
      final output = await _encode(await _newSandbox());
      expect(output.existsSync(), isTrue);
      expect(output.lengthSync(), greaterThan(0));
    });

    test('ffprobe reports h264 / 320x240 / nb_frames 30 / duration 1.0s', () async {
      final sandbox = await _newSandbox();
      await _encode(sandbox);
      final probe = await _ffprobe(sandbox);
      final streams = probe['streams']! as List<Object?>;
      expect(streams, hasLength(1), reason: '-an must keep the output video-only');
      final stream = streams.single! as Map<String, Object?>;
      expect(stream['codec_name'], 'h264');
      expect(stream['width'], _width);
      expect(stream['height'], _height);
      expect(stream['nb_frames'], '$_frameCount');
      final format = probe['format']! as Map<String, Object?>;
      expect(double.parse(format['duration']! as String), closeTo(1.0, 1e-6));
    });

    test('same-machine double encode is byte-identical (bitexact quartet)', () async {
      final first = await _encode(await _newSandbox());
      final second = await _encode(await _newSandbox());
      expect(await first.readAsBytes(), await second.readAsBytes());
    });

    test('decode-back frame hashes are equal between the two encodes', () async {
      // D12: compared between encodes, never against the source (h264 is lossy).
      final sandboxA = await _newSandbox();
      final sandboxB = await _newSandbox();
      await _encode(sandboxA);
      await _encode(sandboxB);
      final hashesA = await _decodedFrameHashes(sandboxA);
      final hashesB = await _decodedFrameHashes(sandboxB);
      expect(hashesA, hasLength(_frameCount));
      expect(hashesA, hashesB);
    });

    test('a truncated frames.rgba yields FluvieEncodeException with a stderr tail', () async {
      final sandbox = await _newSandbox();
      // Less than one full frame: the rawvideo demuxer must hard-fail.
      await File('${sandbox.path}/frames.rgba').writeAsBytes(_gradientFrame(0).sublist(0, 100));
      await expectLater(
        () => ProcessFfmpegProvider().encode(args: _encodeArgs(), sandbox: sandbox),
        throwsA(
          isA<FluvieEncodeException>()
              .having((e) => e.exitCode, 'exitCode', isNot(0))
              .having((e) => e.stderrTail, 'stderrTail', isNotEmpty),
        ),
      );
    });

    test('the real binary probes to a version meeting the >= 6.0 floor', () async {
      final version = await ProcessFfmpegProvider().probeVersion();
      expect(version, isNotNull);
      expect(version!.meetsFloor, isTrue);
      expect(version.major, greaterThanOrEqualTo(6));
    });

    test('FfprobeVideoProbeService probes the encoded output (real ffprobe)', () async {
      final sandbox = await _newSandbox();
      final output = await _encode(sandbox);

      final result = await const FfprobeVideoProbeService().probe(output.path);

      expect(result.codec, 'h264');
      expect(result.width, _width);
      expect(result.height, _height);
      expect(result.nbFrames, _frameCount);
      expect(result.durationSeconds, closeTo(1.0, 1e-6));
    });
  });
}
