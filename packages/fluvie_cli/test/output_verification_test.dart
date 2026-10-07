import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/output_verification.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:test/test.dart';

void main() {
  test('verifies the encoded artifact against resolved output intent', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_verify_');
    addTearDown(() => directory.delete(recursive: true));
    final output = File('${directory.path}/cat.mp4')..writeAsBytesSync([1]);
    final runner = _Runner();
    final result = await verifyOutput(
      output.path,
      ffprobeBinary: '/tools/ffprobe',
      runner: runner,
      expected: {
        'width': 32,
        'height': 16,
        'fps': 2.0,
        'frameCount': 2,
        'durationSeconds': 1.0,
        'codec': 'h264',
        'container': 'mp4',
        'hasAudio': true,
        'hasAlpha': false,
      },
    );
    expect(result['ok'], isTrue);
    expect(result['mismatches'], isEmpty);
    expect(result['observed'], containsPair('frameCount', 2));
    final wrong = await verifyOutput(
      output.path,
      runner: runner,
      expected: {'width': 100, 'codec': 'vp9', 'hasAlpha': true, 'hasAudio': false},
    );
    expect(wrong['ok'], isFalse);
    expect(
      (wrong['mismatches']! as List<Object?>).map(
        (item) => (item! as Map<String, Object?>)['code'],
      ),
      ['width', 'codec', 'hasAudio', 'hasAlpha'],
    );
  });

  test('counts headerless video frames and reports full-decode corruption', () async {
    final runner = _Runner(headerless: true, decodeFailure: true);
    final result = await verifyOutput(
      '/fixtures/render.webm',
      expected: {'frameCount': 2},
      runner: runner,
      strictDecode: true,
      ffmpegBinary: '/tools/ffmpeg',
      ffprobeBinary: '/tools/ffprobe',
    );
    expect(result['observed'], containsPair('frameCount', 2));
    expect(result['ok'], isFalse);
    expect(result['strictDecode'], isTrue);
    expect(result['mismatches'], [containsPair('code', 'decode')]);
    expect(runner.calls.any((args) => args.contains('-count_frames')), isTrue);
    expect(runner.calls.last, containsAll(['-xerror', '-map', '0:a?']));
  });

  test('rejects invalid intent and reports non-video output', () async {
    await expectLater(
      verifyOutput('/fixture', expected: {'fps': double.nan}),
      throwsFormatException,
    );
    final result = await verifyOutput('/fixture', runner: _Runner(noVideo: true));
    expect(result['ok'], isFalse);
    expect(result['mismatches'], [containsPair('code', 'videoStream')]);
  });
}

final class _Runner implements ProcessRunner {
  _Runner({this.headerless = false, this.decodeFailure = false, this.noVideo = false});
  final bool headerless;
  final bool decodeFailure;
  final bool noVideo;
  final calls = <List<String>>[];
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls.add(args);
    if (args.contains('-count_frames')) {
      return const ProcessRunResult(
        exitCode: 0,
        stderr: '',
        stdout: '{"streams":[{"nb_read_frames":"2"}]}',
      );
    }
    if (args.contains('-xerror')) {
      return ProcessRunResult(
        exitCode: decodeFailure ? 1 : 0,
        stderr: decodeFailure ? 'corrupt frame' : '',
        stdout: '',
      );
    }
    return ProcessRunResult(
      exitCode: 0,
      stderr: '',
      stdout: jsonEncode({
        'streams': [
          if (!noVideo)
            {
              'codec_type': 'video',
              'codec_name': 'h264',
              'width': 32,
              'height': 16,
              'pix_fmt': 'yuv420p',
              'avg_frame_rate': '2/1',
              if (!headerless) 'nb_frames': '2',
            },
          {'codec_type': 'audio', 'codec_name': 'aac', 'channels': 1},
        ],
        'format': {'format_name': 'mov,mp4,m4a,3gp,3g2,mj2', 'duration': '1.000'},
      }),
    );
  }
}
