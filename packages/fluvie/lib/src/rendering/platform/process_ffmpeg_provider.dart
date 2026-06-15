import 'dart:io';

import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_version.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';

/// The native [FfmpegProvider]: spawns a local FFmpeg binary through a
/// [ProcessRunner] with argument arrays, never a shell.
///
/// Binary resolution, in priority order: an explicit `binaryPath`, the
/// `FLUVIE_FFMPEG` environment variable, then `ffmpeg` on `PATH`. Every
/// encode probes first and enforces the `>= 6.0` floor before any work
/// starts; failures surface as [FluvieEncodeException] carrying the exit
/// code and the last 4 KiB of stderr — the actual FFmpeg diagnostic, not a
/// bare "encode failed".
final class ProcessFfmpegProvider implements FfmpegProvider {
  /// Creates a provider running through `runner`.
  ///
  /// `binaryPath` pins the FFmpeg binary explicitly; otherwise `environment`
  /// (defaulting to [Platform.environment]; injectable for tests) is
  /// consulted for [environmentVariable] before falling back to `ffmpeg`.
  ProcessFfmpegProvider({
    this._runner = const IoProcessRunner(),
    this._binaryPath,
    this._environment,
  });

  /// The environment variable that overrides the `ffmpeg` PATH lookup.
  static const String environmentVariable = 'FLUVIE_FFMPEG';

  /// How much trailing stderr is retained for diagnostics (4 KiB).
  static const int stderrTailLength = 4096;

  final ProcessRunner _runner;
  final String? _binaryPath;
  final Map<String, String>? _environment;

  String get _binary =>
      _binaryPath ?? (_environment ?? Platform.environment)[environmentVariable] ?? 'ffmpeg';

  @override
  Future<FfmpegVersion?> probeVersion() => _probe();

  @override
  Future<void> encode({required List<String> args, required Directory sandbox}) async {
    final version = await _probe();
    if (!version.meetsFloor) {
      throw FluvieEncodeException(
        'FFmpeg ${FfmpegVersion.floorMajor}.0 or newer is required, but "$_binary" '
        'is version $version. Install a newer FFmpeg or point binaryPath / '
        '\$$environmentVariable at one.',
      );
    }
    final result = await _runner.run(_binary, args, workingDirectory: sandbox.path);
    if (result.exitCode != 0) {
      throw FluvieEncodeException(
        'FFmpeg ("$_binary") exited non-zero while encoding.',
        exitCode: result.exitCode,
        stderrTail: _tail(result.stderr),
      );
    }
  }

  /// Probes `[_binary, '-version']`; unlike the nullable contract method this
  /// never returns `null` — an unusable binary is a typed failure here.
  Future<FfmpegVersion> _probe() async {
    final result = await _runner.run(_binary, const ['-version']);
    if (result.exitCode != 0) {
      throw FluvieEncodeException(
        'Could not probe "$_binary -version". Is FFmpeg installed and on PATH '
        '(or set via binaryPath / \$$environmentVariable)?',
        exitCode: result.exitCode,
        stderrTail: _tail(result.stderr),
      );
    }
    final version = FfmpegVersion.parse(result.stdout);
    if (version == null) {
      throw FluvieEncodeException(
        'The version banner of "$_binary" is unparsable; pass an explicit '
        'binaryPath to ProcessFfmpegProvider pointing at a release FFmpeg build.',
      );
    }
    return version;
  }

  static String _tail(String stderr) => stderr.length <= stderrTailLength
      ? stderr
      : stderr.substring(stderr.length - stderrTailLength);
}
