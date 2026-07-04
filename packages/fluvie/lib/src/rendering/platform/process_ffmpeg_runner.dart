import 'dart:io';

import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_version.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';

/// The native [FfmpegRunner]: spawns a local FFmpeg binary through a
/// [ProcessRunner] with argument arrays, never a shell.
///
/// Binary resolution, in priority order: an explicit `binaryPath`, the
/// `FLUVIE_FFMPEG` environment variable, the managed cache build that
/// `fluvie ffmpeg install` writes (so a provisioned FFmpeg is found without
/// any setup), then `ffmpeg` on `PATH`. Every encode probes first and enforces
/// the `>= 6.0` floor before any work starts; failures surface as
/// [FluvieEncodeException] carrying the exit code and the last 4 KiB of
/// stderr — the actual FFmpeg diagnostic, not a bare "encode failed".
final class ProcessFfmpegRunner implements FfmpegRunner {
  /// Creates a provider running through `runner`.
  ///
  /// `binaryPath` pins the FFmpeg binary explicitly; otherwise `environment`
  /// (defaulting to [Platform.environment]; injectable for tests) is
  /// consulted for [environmentVariable] before falling back to `ffmpeg`.
  ProcessFfmpegRunner({
    this._runner = const IoProcessRunner(),
    this._binaryPath,
    this._environment,
  });

  /// The environment variable that overrides the `ffmpeg` PATH lookup.
  static const String environmentVariable = 'FLUVIE_FFMPEG';

  /// How much trailing stderr is retained for diagnostics (4 KiB).
  static const int stderrTailLength = 4096;

  /// The cache subdirectory of the FFmpeg build `fluvie ffmpeg install`
  /// provisions. Kept in sync with `fluvie_cli`'s `pinnedFfmpegVersion` (the
  /// CLI owns provisioning; this library only reads the cache it populates).
  static const String _managedFfmpegVersion = '8.1';

  final ProcessRunner _runner;
  final String? _binaryPath;
  final Map<String, String>? _environment;

  String get _binary =>
      _binaryPath ??
      (_environment ?? Platform.environment)[environmentVariable] ??
      _managedCacheBinary() ??
      'ffmpeg';

  /// The managed-cache FFmpeg path when present on disk, else `null`. Mirrors
  /// `fluvie_cli`'s cache convention: `<cacheRoot>/fluvie/ffmpeg/<version>/`,
  /// rooted at `%LOCALAPPDATA%` on Windows or `$XDG_CACHE_HOME` / `~/.cache`
  /// elsewhere.
  String? _managedCacheBinary() {
    final env = _environment ?? Platform.environment;
    final base = Platform.isWindows
        ? _nonEmpty(env['LOCALAPPDATA'])
        : _nonEmpty(env['XDG_CACHE_HOME']) ?? _cacheUnderHome(env['HOME']);
    if (base == null) return null;
    final sep = Platform.pathSeparator;
    final name = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final path = [base, 'fluvie', 'ffmpeg', _managedFfmpegVersion, name].join(sep);
    return File(path).existsSync() ? path : null;
  }

  static String? _cacheUnderHome(String? home) =>
      _nonEmpty(home) == null ? null : '$home${Platform.pathSeparator}.cache';

  static String? _nonEmpty(String? value) => (value == null || value.isEmpty) ? null : value;

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
        'binaryPath to ProcessFfmpegRunner pointing at a release FFmpeg build.',
      );
    }
    return version;
  }

  static String _tail(String stderr) => stderr.length <= stderrTailLength
      ? stderr
      : stderr.substring(stderr.length - stderrTailLength);
}
