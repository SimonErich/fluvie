import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_archive_extractor.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:test/test.dart';

/// The fake ffmpeg payload every fixture nests under its inner path.
final _payload = Uint8List.fromList(List<int>.generate(512, (i) => i % 256));

Archive _archiveWith(String name, List<int> bytes) =>
    // A decoy file proves the extractor selects by name, not by position.
    Archive()
      ..add(ArchiveFile('some/other/README.txt', 3, [1, 2, 3]))
      ..add(ArchiveFile(name, bytes.length, bytes));

void main() {
  group('extractFfmpegBinary', () {
    test('pulls the nested binary out of a tar.xz', () {
      final tar = TarEncoder().encode(_archiveWith('build/bin/ffmpeg', _payload));
      final xz = XZEncoder().encode(tar);

      final bytes = extractFfmpegBinary(
        archiveBytes: xz,
        format: FfmpegArchiveFormat.tarXz,
        innerPath: 'build/bin/ffmpeg',
      );

      expect(bytes, equals(_payload));
    });

    test('pulls the binary out of a zip', () {
      final zip = ZipEncoder().encode(_archiveWith('build/bin/ffmpeg.exe', _payload));

      final bytes = extractFfmpegBinary(
        archiveBytes: zip,
        format: FfmpegArchiveFormat.zip,
        innerPath: 'build/bin/ffmpeg.exe',
      );

      expect(bytes, equals(_payload));
    });

    test('throws a CliFailure when the inner path is absent', () {
      final zip = ZipEncoder().encode(_archiveWith('build/bin/ffmpeg', _payload));

      expect(
        () => extractFfmpegBinary(
          archiveBytes: zip,
          format: FfmpegArchiveFormat.zip,
          innerPath: 'nope/ffmpeg',
        ),
        throwsA(
          isA<CliFailure>().having((e) => e.message, 'message', contains('nope/ffmpeg')),
        ),
      );
    });
  });
}
