import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:path/path.dart' as p;

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
    return prov.install(force: cachedBinary != null && File(cachedBinary).existsSync(), log: log);
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

/// A resolved pair shared by capture, probing, decoding and encoding.
final class FfmpegToolchain {
  /// Creates a toolchain descriptor with exact executable paths.
  const FfmpegToolchain({
    required this.ffmpegPath,
    required this.ffprobePath,
    required this.build,
    required this.ffmpegVersion,
    required this.ffprobeVersion,
  });

  /// The encoder and decoder executable.
  final String ffmpegPath;

  /// The stream-probing executable.
  final String ffprobePath;

  /// Managed build identity, or `system` / `custom`.
  final String build;

  /// Full version banners retained in render receipts.
  final String ffmpegVersion;

  /// Companion probe version banner.
  final String ffprobeVersion;

  /// Environment overrides for every subprocess in a render.
  Map<String, String> get environment => {
    'FLUVIE_FFMPEG': ffmpegPath,
    'FLUVIE_FFPROBE': ffprobePath,
  };

  /// Machine-readable diagnostics and reproducibility metadata.
  Map<String, Object> toJson() => {
    'ffmpeg': ffmpegPath,
    'ffprobe': ffprobePath,
    'build': build,
    'ffmpegVersion': ffmpegVersion,
    'ffprobeVersion': ffprobeVersion,
  };
}

/// Resolves a complete toolchain. The default manages a pinned pair; `system`
/// explicitly selects PATH. Named binaries never silently fall back.
Future<FfmpegToolchain> ensureFfmpegToolchain(
  ProcessRunner runner, {
  String? binary,
  String? probeBinary,
  String mode = 'managed',
  bool allowDownload = true,
  Map<String, String>? environment,
  FfmpegCache? cache,
  FfmpegInstaller? provisioner,
  ProvisionLog log = _silent,
}) async {
  if (mode != 'managed' && mode != 'system') {
    throw const CliFailure('Choose --toolchain managed or --toolchain system.');
  }
  final env = environment ?? Platform.environment;
  final resolvedCache = cache ?? FfmpegCache(environment: env);
  final named = _nonEmpty(binary) ?? _nonEmpty(env['FLUVIE_FFMPEG']);
  final namedProbe = _nonEmpty(probeBinary) ?? _nonEmpty(env['FLUVIE_FFPROBE']);
  late String ffmpeg;
  late String ffprobe;
  late String build;
  if (named != null || mode == 'system') {
    ffmpeg = named ?? 'ffmpeg';
    ffprobe = namedProbe ?? _siblingProbe(ffmpeg);
    build = named == null && namedProbe == null ? 'system' : 'custom';
  } else {
    ffmpeg = resolvedCache.binaryPath ?? '';
    ffprobe = resolvedCache.probePath ?? '';
    final complete =
        ffmpeg.isNotEmpty &&
        File(ffmpeg).existsSync() &&
        File(ffprobe).existsSync() &&
        await _probeFailure(runner, ffmpeg) == null &&
        await _toolBanner(runner, ffprobe, 'ffprobe') != null;
    if (!complete) {
      if (!allowDownload) {
        throw const CliFailure(
          'No usable managed FFmpeg/ffprobe pair is cached and --no-download is set. '
          'Warm it with `fluvie ffmpeg install`, use --toolchain system, '
          'or pass --ffmpeg and --ffprobe.',
        );
      }
      final installer = provisioner ?? FfmpegProvisioner(runner: runner, cache: resolvedCache);
      ffmpeg = await installer.install(force: true, log: log);
      ffprobe = resolvedCache.probePath ?? _siblingProbe(ffmpeg);
    }
    ffprobe = namedProbe ?? ffprobe;
    build = namedProbe == null ? resolvedCache.version : 'custom';
  }
  final failure = await _probeFailure(runner, ffmpeg);
  if (failure != null) throw CliFailure('$failure $_installHint');
  final probeBanner = await _toolBanner(runner, ffprobe, 'ffprobe');
  if (probeBanner == null) {
    throw CliFailure(
      'Could not run a compatible ffprobe at "$ffprobe". '
      'Pass --ffprobe / FLUVIE_FFPROBE, or run `fluvie ffmpeg install` for both tools.',
    );
  }
  return FfmpegToolchain(
    ffmpegPath: _executablePath(ffmpeg, env),
    ffprobePath: _executablePath(ffprobe, env),
    build: build,
    ffmpegVersion: (await runner.run(ffmpeg, const ['-version'])).stdout.split('\n').first.trim(),
    ffprobeVersion: probeBanner,
  );
}

String _siblingProbe(String ffmpeg) {
  if (ffmpeg == 'ffmpeg' || ffmpeg == 'ffmpeg.exe') {
    return Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';
  }
  return p.join(p.dirname(ffmpeg), Platform.isWindows ? 'ffprobe.exe' : 'ffprobe');
}

String _executablePath(String executable, Map<String, String> environment) {
  if (p.isAbsolute(executable)) return p.normalize(executable);
  if (p.dirname(executable) != '.') return p.absolute(executable);
  for (final directory in (environment['PATH'] ?? '').split(Platform.isWindows ? ';' : ':')) {
    if (directory.isEmpty) continue;
    final candidate = p.join(directory, executable);
    if (File(candidate).existsSync()) return p.absolute(candidate);
  }
  return executable;
}

Future<String?> _toolBanner(ProcessRunner runner, String path, String tool) async {
  try {
    final result = await runner.run(path, const ['-version']);
    if (result.exitCode != 0) return null;
    final banner = result.stdout.split('\n').first.trim();
    final match = RegExp('^$tool version [^0-9]{0,2}(\\d+)\\.(\\d+)').firstMatch(banner);
    return match != null && int.parse(match.group(1)!) >= ffmpegFloorMajor ? banner : null;
  } on ProcessException {
    return null;
  }
}
