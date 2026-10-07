import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/output_verification.dart';
import 'package:fluvie_cli/src/render_receipt.dart';
import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'real encoded video is probed and corrupt output is rejected',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_output_probe_');
      addTearDown(() => directory.delete(recursive: true));
      final tools = FfmpegMediaTools();
      addTearDown(tools.close);
      final output = File('${directory.path}/video.mp4');
      final encoded = await tools.run(tools.ffmpegPath, [
        '-v',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'color=c=red:size=32x16:rate=2:duration=1',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=48000:duration=1',
        '-c:v',
        'libx264',
        '-c:a',
        'aac',
        '-shortest',
        output.path,
      ]);
      expect(encoded.exitCode, 0, reason: encoded.stderr);
      final receipt = await writeRenderReceipt(
        outputPath: output.path,
        sourceFingerprint: 'fixture',
        inputs: {},
        toolchain: {},
        options: {},
        ffprobeBinary: tools.ffprobePath,
      );
      final identity = receipt['output']! as Map<String, Object?>;
      final media = identity['media']! as Map<String, Object?>;
      expect(media['codec'], 'h264');
      expect(media['width'], 32);
      expect(media['height'], 16);
      expect(media['declaredFrameCount'], 2);
      expect(media['durationSeconds'], closeTo(1, 0.05));
      expect(media['hasAlpha'], isFalse);
      expect(media['audio'], [
        containsPair('codec', 'aac'),
      ]);
      expect(identity['probe'], isA<Map<String, Object?>>());
      final verified = await verifyOutput(
        output.path,
        expected: {
          'codec': 'h264',
          'container': 'mp4',
          'width': 32,
          'height': 16,
          'fps': 2,
          'frameCount': 2,
          'durationSeconds': 1,
          'hasAudio': true,
          'hasAlpha': false,
        },
        strictDecode: true,
        ffprobeBinary: tools.ffprobePath,
        ffmpegBinary: tools.ffmpegPath,
      );
      expect(verified['ok'], isTrue, reason: jsonEncode(verified));

      final corrupt = File('${directory.path}/corrupt.mp4')..writeAsStringSync('not a video');
      await expectLater(
        writeRenderReceipt(
          outputPath: corrupt.path,
          sourceFingerprint: 'fixture',
          inputs: {},
          toolchain: {},
          options: {},
          ffprobeBinary: tools.ffprobePath,
        ),
        throwsA(isA<CliFailure>()),
      );
      expect(File('${directory.path}/corrupt.render.json').existsSync(), isFalse);
    },
    skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test('image sequences verify every picture geometry and count', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_sequence_verify_');
    addTearDown(() => directory.delete(recursive: true));
    final tools = FfmpegMediaTools();
    addTearDown(tools.closeAsync);
    final frames = Directory('${directory.path}/frames')..createSync();
    final encoded = await tools.run(tools.ffmpegPath, [
      '-v',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'color=red:size=32x16:rate=2',
      '-frames:v',
      '2',
      '${frames.path}/%04d.png',
    ]);
    expect(encoded.exitCode, 0, reason: encoded.stderr);
    final expected = {
      'codec': 'png',
      'container': 'png_sequence',
      'width': 32,
      'height': 16,
      'frameCount': 2,
      'hasAudio': false,
    };
    final verified = await verifyOutput(
      frames.path,
      expected: expected,
      ffprobeBinary: tools.ffprobePath,
      ffmpegBinary: tools.ffmpegPath,
      strictDecode: true,
    );
    expect(verified['ok'], isTrue, reason: jsonEncode(verified));
    final changed = await tools.run(tools.ffmpegPath, [
      '-v',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'color=red:size=64x16:rate=2',
      '-frames:v',
      '1',
      '-update',
      '1',
      '${frames.path}/0002.png',
    ]);
    expect(changed.exitCode, 0, reason: changed.stderr);
    final invalid = await verifyOutput(
      frames.path,
      expected: expected,
      ffprobeBinary: tools.ffprobePath,
    );
    expect(invalid['ok'], isFalse);
    expect(invalid['mismatches'], contains(containsPair('code', 'width')));
  }, skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1');

  test('strict decode rejects truncated payload despite valid container headers', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_decode_verify_');
    addTearDown(() => directory.delete(recursive: true));
    final tools = FfmpegMediaTools();
    addTearDown(tools.closeAsync);
    final output = File('${directory.path}/damaged.mp4');
    final encoded = await tools.run(tools.ffmpegPath, [
      '-v',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=64x32:rate=30',
      '-t',
      '2',
      '-c:v',
      'libx264',
      '-movflags',
      '+faststart',
      output.path,
    ]);
    expect(encoded.exitCode, 0, reason: encoded.stderr);
    final size = output.lengthSync();
    final file = await output.open(mode: FileMode.append);
    await file.truncate((size * .75).floor());
    await file.close();
    final headers = await verifyOutput(output.path, ffprobeBinary: tools.ffprobePath);
    expect(headers['ok'], isTrue, reason: jsonEncode(headers));
    final decoded = await verifyOutput(
      output.path,
      strictDecode: true,
      ffmpegBinary: tools.ffmpegPath,
      ffprobeBinary: tools.ffprobePath,
    );
    expect(decoded['ok'], isFalse);
    expect(decoded['mismatches'], contains(containsPair('code', 'decode')));
  }, skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1');
}
