import 'dart:io';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'default samples cover the display timeline and one sample starts at zero',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_contacts_sampling_');
      final tools = FfmpegMediaTools();
      addTearDown(() async {
        await tools.closeAsync();
        await directory.delete(recursive: true);
      });
      final source = '${directory.path}/tiny.mp4';
      final encoded = await tools.run(tools.ffmpegPath, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=red:size=16x16:rate=4',
        '-t',
        '1',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-y',
        source,
      ]);
      expect(encoded.exitCode, 0, reason: encoded.stderr);
      for (final samples in [1, 3, 6]) {
        final sheet = await tools.contactSheet(
          Uri.file(source),
          outputPath: '${directory.path}/$samples.png',
          samples: samples,
          cellWidth: 16,
          cellHeight: 16,
        );
        expect(sheet.cells.first.frameIndex, 0);
        expect(sheet.cells.first.requestedTimeSeconds, 0);
        expect(sheet.cells.last.frameIndex, samples == 1 ? 0 : 3);
        expect(sheet.cells.length, lessThanOrEqualTo(4));
        expect(File(sheet.filePath).existsSync(), isTrue);
        final json = sheet.toJson();
        expect(json['filePath'], sheet.filePath);
        expect(json['cells'], hasLength(sheet.cells.length));
      }
    },
    skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
