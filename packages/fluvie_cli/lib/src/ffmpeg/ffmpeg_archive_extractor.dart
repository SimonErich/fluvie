import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';

/// Extracts the bytes of the `ffmpeg` binary stored at [innerPath] inside
/// [archiveBytes], which are packaged as [format].
///
/// Throws a [CliFailure] when the archive does not contain that entry — the
/// pinned build's inner layout is part of the release table, so a miss means a
/// corrupt download or a stale pin, not bad user input.
Uint8List extractFfmpegBinary({
  required List<int> archiveBytes,
  required FfmpegArchiveFormat format,
  required String innerPath,
}) {
  final archive = switch (format) {
    FfmpegArchiveFormat.tarXz => TarDecoder().decodeBytes(XZDecoder().decodeBytes(archiveBytes)),
    FfmpegArchiveFormat.zip => ZipDecoder().decodeBytes(archiveBytes),
  };
  for (final file in archive) {
    if (file.isFile && file.name == innerPath) return file.content;
  }
  throw CliFailure(
    'The downloaded FFmpeg archive did not contain "$innerPath". '
    'The pinned build may be corrupt; rerun `fluvie ffmpeg install --force`.',
  );
}
