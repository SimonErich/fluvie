import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_receipt.dart';
import 'package:test/test.dart';

void main() {
  test('retains a machine artifact receipt and hashes actual encoded bytes', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_receipt_test_');
    addTearDown(() => directory.delete(recursive: true));
    final video = File('${directory.path}/my cat.mp4');
    final bytes = List<int>.generate(1024 * 1024 + 3, (index) => index % 256);
    await video.writeAsBytes(bytes);
    final receipt = await writeRenderReceipt(
      outputPath: video.path,
      sourceFingerprint: 'source-identity',
      source: 'lib/my_video.dart',
      inputs: {
        'files': [
          {'path': 'assets/cat.mov', 'sha256': 'cat-identity'},
        ],
      },
      toolchain: {'build': 'pinned-build', 'ffmpeg': '/cache/bin/ffmpeg'},
      options: {'alpha': false},
      captureManifest: {'width': 1080, 'height': 1920, 'fps': 30, 'totalFrames': 120},
    );
    expect(receipt['event'], 'artifact');
    expect(receipt['filePath'], video.path);
    expect(receipt['output'], {
      'path': video.path,
      'byteLength': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    });
    final saved = File(receipt['receiptPath']! as String);
    expect(saved.path, '${directory.path}/my cat.render.json');
    expect(jsonDecode(await saved.readAsString()), receipt);
    expect(directory.listSync().where((entry) => entry.path.endsWith('.tmp')), isEmpty);
    await writeRenderReceipt(
      outputPath: video.path,
      sourceFingerprint: 'edited',
      inputs: {},
      toolchain: {},
      options: {},
    );
    expect(
      (jsonDecode(await saved.readAsString()) as Map<String, Object?>)['sourceFingerprint'],
      'edited',
    );
  });

  test('a missing output never writes a misleading successful receipt', () async {
    await expectLater(
      writeRenderReceipt(
        outputPath: '/no/such/video.mp4',
        sourceFingerprint: '',
        inputs: {},
        toolchain: {},
        options: {},
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('image sequence receipt records ordered frame hashes and total bytes', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_sequence_receipt_');
    addTearDown(() => directory.delete(recursive: true));
    final frames = Directory('${directory.path}/frames')..createSync();
    File('${frames.path}/0002.png').writeAsBytesSync([2, 3]);
    File('${frames.path}/0001.png').writeAsBytesSync([1]);
    final result = await writeRenderReceipt(
      outputPath: frames.path,
      sourceFingerprint: 'source',
      inputs: {},
      toolchain: {},
      options: {},
    );
    final output = result['output']! as Map<String, Object?>;
    expect(output['kind'], 'directory');
    expect(output['byteLength'], 3);
    final files = output['files']! as List<Map<String, Object?>>;
    expect(files.map((file) => file['path']), ['0001.png', '0002.png']);
    expect(files.first['sha256'], sha256.convert([1]).toString());
    expect(File('${directory.path}/frames.render.json').existsSync(), isTrue);
  });

  test('probes the actual encoded artifact and retains poster identity', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_verified_receipt_');
    addTearDown(() => directory.delete(recursive: true));
    final video = File('${directory.path}/render.webm')..writeAsBytesSync([1, 2]);
    final poster = File('${directory.path}/render.poster.png')..writeAsBytesSync([3, 4, 5]);
    final report = {
      'streams': [
        {
          'codec_type': 'video',
          'codec_name': 'vp9',
          'width': 1920,
          'height': 1080,
          'pix_fmt': 'yuv420p',
          'tags': {'alpha_mode': '1'},
          'avg_frame_rate': '30/1',
          'nb_frames': '60',
        },
        {'codec_type': 'audio', 'codec_name': 'opus', 'channels': 2, 'sample_rate': '48000'},
      ],
      'format': {'format_name': 'matroska,webm', 'duration': '2.000'},
    };
    final runner = _ProbeRunner(jsonEncode(report));
    final receipt = await writeRenderReceipt(
      outputPath: video.path,
      sourceFingerprint: 'source',
      inputs: {},
      toolchain: {},
      options: {},
      ffprobeBinary: '/managed/bin/ffprobe',
      runner: runner,
      posterPath: poster.path,
    );
    expect(runner.executable, '/managed/bin/ffprobe');
    expect(runner.arguments.last, video.path);
    final output = receipt['output']! as Map<String, Object?>;
    expect(output['probe'], report);
    final media = output['media']! as Map<String, Object?>;
    expect(media['codec'], 'vp9');
    expect(media['hasAlpha'], isTrue);
    expect(media['declaredFrameCount'], 60);
    expect(media['durationSeconds'], 2);
    expect(media['audio'], [
      {'codec': 'opus', 'channels': 2, 'sampleRate': '48000'},
    ]);
    expect(receipt['poster'], {
      'path': poster.path,
      'byteLength': 3,
      'sha256': sha256.convert([3, 4, 5]).toString(),
    });
  });

  test('unreadable or non-video output never receives a successful receipt', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_bad_output_');
    addTearDown(() => directory.delete(recursive: true));
    final output = File('${directory.path}/bad.mp4')..writeAsBytesSync([1]);
    for (final runner in [_ProbeRunner('not JSON'), _ProbeRunner('{"streams": []}')]) {
      await expectLater(
        writeRenderReceipt(
          outputPath: output.path,
          sourceFingerprint: 'source',
          inputs: {},
          toolchain: {},
          options: {},
          ffprobeBinary: '/managed/bin/ffprobe',
          runner: runner,
        ),
        throwsA(isA<CliFailure>()),
      );
      expect(File('${directory.path}/bad.render.json').existsSync(), isFalse);
    }
  });

  test(
    'intent mismatch retains a failure receipt and compact events omit file inventory',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_intent_receipt_');
      addTearDown(() => directory.delete(recursive: true));
      final output = File('${directory.path}/wrong.mp4')..writeAsBytesSync([1]);
      final runner = _ProbeRunner(
        jsonEncode({
          'streams': [
            {'codec_type': 'video', 'codec_name': 'h264', 'width': 32, 'height': 16},
          ],
        }),
      );
      await expectLater(
        writeRenderReceipt(
          outputPath: output.path,
          sourceFingerprint: 'source',
          inputs: {},
          toolchain: {},
          options: {},
          ffprobeBinary: '/tools/ffprobe',
          runner: runner,
          captureManifest: {
            'outputIntent': {'width': 100},
          },
        ),
        throwsA(
          isA<CliFailure>()
              .having((error) => error.code, 'stable code', 'output_verification_failed')
              .having(
                (error) => error.details['receiptPath'],
                'failure receipt',
                endsWith('wrong.failed.render.json'),
              )
              .having(
                (error) => error.message,
                'actionable mismatch',
                contains('width: expected 100, got 32'),
              ),
        ),
      );
      expect(File('${directory.path}/wrong.render.json').existsSync(), isFalse);
      final failed =
          jsonDecode(await File('${directory.path}/wrong.failed.render.json').readAsString())
              as Map<String, Object?>;
      expect(failed['event'], 'artifactFailure');
      expect(failed['verification'], containsPair('ok', false));
      final receipt = await writeRenderReceipt(
        outputPath: output.path,
        sourceFingerprint: 'source',
        inputs: {
          'files': List<Object?>.filled(10000, {'path': 'large/inventory'}),
        },
        toolchain: {},
        options: {},
        ffprobeBinary: '/tools/ffprobe',
        runner: runner,
        captureManifest: {
          'outputIntent': {'width': 32},
        },
      );
      final event = renderArtifactEvent(receipt);
      expect(event['receiptPath'], receipt['receiptPath']);
      expect(event['verification'], containsPair('ok', true));
      expect(jsonEncode(event).length, lessThan(4096));
      expect((receipt['inputs']! as Map<String, Object?>)['files'], hasLength(10000));
    },
  );
}

final class _ProbeRunner implements ProcessRunner {
  _ProbeRunner(this.report);
  final String report;
  late String executable;
  late List<String> arguments;

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    this.executable = executable;
    arguments = args;
    return ProcessRunResult(exitCode: 0, stdout: report, stderr: '');
  }
}
