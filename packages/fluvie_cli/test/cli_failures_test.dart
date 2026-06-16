import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:test/test.dart';

/// The two failure exceptions print their message verbatim, because the CLI
/// boundary writes `toString()` straight to stderr before exiting.
void main() {
  test('CliFailure.toString is its message (printed to stderr at exit 1)', () {
    const failure = CliFailure('ffmpeg is not on PATH');
    expect(failure.toString(), 'ffmpeg is not on PATH');
    expect(failure.message, 'ffmpeg is not on PATH');
  });

  test('UsageFailure.toString is its message (printed to stderr at exit 64)', () {
    const failure = UsageFailure('--format must be one of mp4, gif');
    expect(failure.toString(), '--format must be one of mp4, gif');
    expect(failure.message, '--format must be one of mp4, gif');
  });
}
