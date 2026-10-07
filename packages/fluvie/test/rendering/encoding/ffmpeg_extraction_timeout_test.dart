import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';

void main() {
  test('timed-out extraction terminates its native decoder before returning', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_extract_timeout_');
    final pidFile = File('${root.path}/decoder.pid');
    final decoder = File('${root.path}/decoder');
    final quotedPidPath = "'${pidFile.path.replaceAll("'", r"'\''")}'";
    await decoder.writeAsString(
      '#!/bin/sh\n'
      '${r'printf "%s" "$$" > '}$quotedPidPath\n'
      'exec /bin/sleep 20\n',
    );
    await Process.run('chmod', ['+x', decoder.path]);
    int? decoderPid;
    try {
      final service = FfmpegFrameExtractionService(
        binaryPath: decoder.path,
        timeout: const Duration(milliseconds: 300),
      );
      await expectLater(
        service.extractFrames(Uri.file('${root.path}/clip.mp4'), [0], width: 1, height: 1),
        throwsA(
          isA<FluvieRenderException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      expect(pidFile.existsSync(), isTrue, reason: 'The real decoder must have started.');
      decoderPid = int.parse(await pidFile.readAsString());
      expect(
        Process.killPid(decoderPid, ProcessSignal.sigcont),
        isFalse,
        reason:
            'Timeout must stop and reap the owned decoder, rather than only completing its Future.',
      );
    } finally {
      if (decoderPid != null) Process.killPid(decoderPid, ProcessSignal.sigkill);
      if (pidFile.existsSync() && decoderPid == null) {
        Process.killPid(int.parse(await pidFile.readAsString()), ProcessSignal.sigkill);
      }
      await root.delete(recursive: true);
    }
  }, skip: Platform.isWindows ? 'The deterministic process fixture uses /bin/sh.' : false);
}
