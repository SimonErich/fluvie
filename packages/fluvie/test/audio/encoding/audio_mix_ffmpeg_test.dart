@Tags(['ffmpeg'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_plan.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_filter_graph_builder.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_provider.dart';

const _width = 160;
const _height = 120;
const _fps = 30;
const _frameCount = 30;
const int _frameBytes = _width * _height * 4;

Future<Directory> _newSandbox() async {
  final sandbox = await Directory.systemTemp.createTemp('fluvie_audio_mix_');
  addTearDown(() => sandbox.delete(recursive: true));
  return sandbox;
}

Future<void> _writeFrames(Directory sandbox) async {
  final sink = File('${sandbox.path}/frames.rgba').openWrite();
  for (var frame = 0; frame < _frameCount; frame++) {
    final bytes = Uint8List(_frameBytes);
    for (var i = 0; i < _frameBytes; i += 4) {
      bytes[i] = (frame * 8) % 256;
      bytes[i + 3] = 255;
    }
    sink.add(bytes);
  }
  await sink.close();
}

/// Generates a sine tone WAV into [sandbox] under [name] (a bare file name).
Future<void> _genTone(Directory sandbox, String name, {required int frequency}) async {
  final result = await Process.run('ffmpeg', [
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=$frequency:duration=1',
    '-ar',
    '44100',
    '-ac',
    '2',
    name,
  ], workingDirectory: sandbox.path);
  expect(result.exitCode, 0, reason: 'tone generation failed: ${result.stderr}');
}

Future<Map<String, Object?>> _ffprobe(Directory sandbox) async {
  final result = await Process.run('ffprobe', const [
    '-v',
    'error',
    '-print_format',
    'json',
    '-show_streams',
    'out.mp4',
  ], workingDirectory: sandbox.path);
  expect(result.exitCode, 0, reason: 'ffprobe failed: ${result.stderr}');
  return jsonDecode(result.stdout as String) as Map<String, Object?>;
}

void main() {
  setUpAll(() async {
    final ffprobe = await Process.run('ffprobe', const ['-version']);
    expect(ffprobe.exitCode, 0, reason: 'this suite needs ffmpeg + ffprobe on PATH');
  });

  test('a music track plus an sfx mix into one audio stream alongside the video', () async {
    final sandbox = await _newSandbox();
    await _writeFrames(sandbox);
    await _genTone(sandbox, 'music.wav', frequency: 220);
    await _genTone(sandbox, 'sfx.wav', frequency: 880);

    // The typed mix plan: a music bed and a delayed one-shot, both gained.
    final plan = buildAudioMixPlan(const [
      AudioTrackNode(name: 'music.wav', volume: 0.6, fadeInSeconds: 0.2),
      AudioTrackNode(name: 'sfx.wav', delayMs: 300, volume: 0.9),
    ]);

    final filters = const FfmpegFilterGraphBuilder().forFrames(width: _width, height: _height);
    final args =
        (FfmpegArgsBuilder()
              ..addRawVideoInput(name: 'frames.rgba', width: _width, height: _height, fps: _fps)
              ..setH264Output(
                name: 'out.mp4',
                quality: Quality.low,
                fps: _fps,
                filters: filters,
                audio: plan.tracks,
                amix: plan.amix,
              ))
            .build();

    await ProcessFfmpegProvider().encode(args: args, sandbox: sandbox);

    final probe = await _ffprobe(sandbox);
    final streams = (probe['streams']! as List<Object?>).cast<Map<String, Object?>>();
    final kinds = [for (final stream in streams) stream['codec_type']];
    expect(kinds, containsAll(<String>['video', 'audio']));
    final audio = streams.firstWhere((stream) => stream['codec_type'] == 'audio');
    expect(audio['codec_name'], 'aac');
  });
}
