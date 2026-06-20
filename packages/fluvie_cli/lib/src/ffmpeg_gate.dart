import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/process_runner.dart';

/// The lowest FFmpeg major version the CLI accepts.
const int ffmpegFloorMajor = 6;

const String _installHint =
    'Run `fluvie ffmpeg install` to download a pinned FFmpeg build, or point '
    r'--ffmpeg / $FLUVIE_FFMPEG at an FFmpeg 6.0 (or newer) binary.';

/// Matches the `major.minor` pair on the banner's first line only (tolerating
/// `n7.0` git tags and distro suffixes). Anchoring keeps a git-snapshot banner
/// (`ffmpeg version N-...` + `built with gcc 12.2.0`) from silently parsing
/// the compiler's version instead of FFmpeg's.
final RegExp _versionPattern = RegExp(r'^ffmpeg version [^0-9]{0,2}(\d+)\.(\d+)');

void _silent(String _) {}

/// Resolves the FFmpeg binary to use — **before any capture** — and returns its
/// path, downloading the pinned build when nothing usable is found.
///
/// Resolution order: an explicit [binary] (the `--ffmpeg` flag), then
/// `$FLUVIE_FFMPEG`, then the managed cache build, then `ffmpeg` on `PATH`. A
/// binary the user named explicitly must work — a probe failure there is fatal,
/// never silently overridden. If none of those resolve and [allowDownload] is
/// true (the default; `--no-download` turns it off), the pinned build is
/// provisioned into the cache and its path returned.
///
/// [environment], [cache] and [provisioner] are injectable for tests; defaults
/// read the process environment and the host cache.
Future<String> ensureFfmpeg(
  ProcessRunner runner, {
  String? binary,
  bool allowDownload = true,
  Map<String, String>? environment,
  FfmpegCache? cache,
  FfmpegInstaller? provisioner,
  ProvisionLog log = _silent,
}) async {
  final env = environment ?? Platform.environment;
  final resolvedCache = cache ?? FfmpegCache(environment: env);

  // 1 & 2: a binary the user named (flag wins over the env var). Fatal on miss.
  final named = (binary != null && binary.isNotEmpty) ? binary : _nonEmpty(env['FLUVIE_FFMPEG']);
  if (named != null) {
    final failure = await _probeFailure(runner, named);
    if (failure != null) throw CliFailure('$failure $_installHint');
    return named;
  }

  // 3: the managed cache build, preferred over PATH for reproducibility. A
  // corrupt cached binary falls through to a fresh provision.
  final cachedBinary = resolvedCache.binaryPath;
  if (cachedBinary != null && File(cachedBinary).existsSync()) {
    if (await _probeFailure(runner, cachedBinary) == null) return cachedBinary;
  }

  // 4: ffmpeg on PATH.
  final pathFailure = await _probeFailure(runner, 'ffmpeg');
  if (pathFailure == null) return 'ffmpeg';

  // 5: auto-provision the pinned build.
  if (allowDownload) {
    final prov = provisioner ?? FfmpegProvisioner(runner: runner, cache: resolvedCache);
    return prov.install(log: log);
  }

  // 6: nothing usable and downloads are disabled.
  throw CliFailure('No usable FFmpeg found ($pathFailure) and --no-download is set. $_installHint');
}

String? _nonEmpty(String? value) => (value == null || value.isEmpty) ? null : value;

/// Probes `[executable, '-version']`; returns `null` when a parsable FFmpeg
/// `>= 6.0` answers, or a human-readable reason string otherwise.
Future<String?> _probeFailure(ProcessRunner runner, String executable) async {
  final ProcessRunResult result;
  try {
    result = await runner.run(executable, const ['-version']);
  } on ProcessException catch (error) {
    return 'could not run "$executable -version" (${error.message})';
  }
  if (result.exitCode != 0) {
    return '"$executable -version" exited with code ${result.exitCode}';
  }
  final match = _versionPattern.firstMatch(result.stdout);
  if (match == null) {
    return 'the version banner of "$executable" is unparsable '
        '(started with "${result.stdout.split('\n').first}")';
  }
  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  if (major < ffmpegFloorMajor) {
    return 'FFmpeg $ffmpegFloorMajor.0 or newer is required, '
        'but "$executable" is version $major.$minor';
  }
  return null;
}
