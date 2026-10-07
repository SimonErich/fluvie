import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'contact sheet pixels have exact source timestamps and preserve portrait geometry',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_contacts_');
      final tools = FfmpegMediaTools();
      addTearDown(() async {
        await tools.closeAsync();
        await directory.delete(recursive: true);
      });
      final source = '${directory.path}/portrait.mp4';
      final encoded = await tools.run(tools.ffmpegPath, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=red:size=16x32:rate=4',
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
      final sheet = await tools.contactSheet(
        Uri.file(source),
        outputPath: '${directory.path}/evidence.png',
        columns: 2,
        cellWidth: 64,
        cellHeight: 48,
        timestamps: [0.1, 0.6],
      );
      expect(sheet.cells.map((cell) => cell.frameIndex), [0, 2]);
      expect(sheet.cells.map((cell) => cell.timeSeconds), [0, 0.5]);
      final png = await File(sheet.filePath).readAsBytes();
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(png);
      expect((header.getUint32(16), header.getUint32(20)), (140, 56));
      final raster = await tools.extractFrames(
        Uri.file(sheet.filePath),
        [0],
        width: 140,
        height: 56,
      );
      final bytes = raster[0]!.rgba;
      List<int> pixel(int x, int y) => bytes.sublist((y * 140 + x) * 4, (y * 140 + x) * 4 + 3);
      expect(pixel(8, 20), [0, 0, 0]);
      expect(pixel(36, 20).first, greaterThan(240));
      expect(pixel(104, 20).first, greaterThan(240));
    },
    skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
