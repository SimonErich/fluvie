import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/process_runner.dart';

/// The lowest FFmpeg major version the CLI accepts.
const int ffmpegFloorMajor = 6;

const String _installHint =
    'Install FFmpeg $ffmpegFloorMajor.0 or newer (e.g. `sudo apt install '
    'ffmpeg`) or point --ffmpeg at a binary.';

/// Matches the `major.minor` pair on the banner's first line only (tolerating
/// `n7.0` git tags and distro suffixes). Anchoring keeps a git-snapshot banner
/// (`ffmpeg version N-...` + `built with gcc 12.2.0`) from silently parsing
/// the compiler's version instead of FFmpeg's.
final RegExp _versionPattern = RegExp(r'^ffmpeg version [^0-9]{0,2}(\d+)\.(\d+)');

/// Probes `[binary, '-version']` and fails fast — **before any capture** —
/// unless a parsable FFmpeg `>= 6.0` answers.
///
/// This is the CLI's own ~30-line probe: the CLI cannot import the Flutter
/// `fluvie` package, so it carries an equivalent of the in-process provider's
/// gate. Unparsable banners are rejected with a clear message, never guessed
/// at.
Future<void> ensureFfmpeg(ProcessRunner runner, {String? binary}) async {
  final executable = binary ?? 'ffmpeg';
  final ProcessRunResult result;
  try {
    result = await runner.run(executable, const ['-version']);
  } on ProcessException catch (error) {
    throw CliFailure('Could not run "$executable -version" (${error.message}). $_installHint');
  }
  if (result.exitCode != 0) {
    throw CliFailure(
      '"$executable -version" exited with code ${result.exitCode}. $_installHint',
    );
  }
  final match = _versionPattern.firstMatch(result.stdout);
  if (match == null) {
    throw CliFailure(
      'The version banner of "$executable" is unparsable; pass --ffmpeg '
      'pointing at a release FFmpeg build. Banner started with: '
      '"${result.stdout.split('\n').first}"',
    );
  }
  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  if (major < ffmpegFloorMajor) {
    throw CliFailure(
      'FFmpeg $ffmpegFloorMajor.0 or newer is required, but "$executable" is '
      'version $major.$minor. $_installHint',
    );
  }
}
