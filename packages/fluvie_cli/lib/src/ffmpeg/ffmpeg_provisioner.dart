import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_archive_extractor.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_downloader.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:path/path.dart' as p;

part 'ffmpeg_provisioner_tools.dart';
part 'ffmpeg_provisioner_lock.dart';

/// A sink for human-readable provisioning progress lines.
typedef ProvisionLog = void Function(String message);

void _noLog(String _) {}

/// Download-and-install seam, injectable for offline tests.
// ignore: one_member_abstracts — injectable installer seam.
abstract interface class FfmpegInstaller {
  /// Installs the complete pinned toolchain and returns its FFmpeg path.
  Future<String> install({bool force, ProvisionLog log});
}

/// Installs a verified FFmpeg/ffprobe pair without administrator privileges.
/// Both binaries are tested before the staged directory replaces the cache.
final class FfmpegProvisioner implements FfmpegInstaller {
  /// Creates an installer with injectable HTTP, processes and cache location.
  FfmpegProvisioner({
    this._runner = const IoProcessRunner(),
    FfmpegDownloader? downloader,
    FfmpegCache? cache,
    this.lockTimeout = const Duration(seconds: 30),
  }) : _downloader = downloader ?? HttpFfmpegDownloader(),
       _cache = cache ?? FfmpegCache();

  /// Maximum wait for another process to finish installing this toolchain.
  final Duration lockTimeout;

  final ProcessRunner _runner;
  final FfmpegDownloader _downloader;
  final FfmpegCache _cache;
  static final _pending = <String, Future<String>>{};

  /// Managed FFmpeg path, even before installation.
  String? get binaryPath => _cache.binaryPath;

  /// Whether both executables are present (installation also probes them).
  bool get isInstalled =>
      _cache.binaryPath != null &&
      File(_cache.binaryPath!).existsSync() &&
      File(_cache.probePath!).existsSync();

  @override
  Future<String> install({
    bool force = false,
    ProvisionLog log = _noLog,
    FfmpegAsset? asset,
  }) async {
    if (lockTimeout.isNegative) {
      throw ArgumentError.value(lockTimeout, 'lockTimeout', 'must not be negative');
    }
    final versionDir = _cache.versionDir;
    if (versionDir == null) {
      throw const CliFailure(
        'Could not resolve a cache directory. Set XDG_CACHE_HOME / HOME '
        '(LOCALAPPDATA on Windows), or pass --ffmpeg and --ffprobe.',
      );
    }
    final pending = _pending[versionDir];
    if (pending != null) return pending;
    late final Future<String> operation;
    final installation = _installLocked(versionDir, force: force, log: log, asset: asset);
    operation = installation.whenComplete(() {
      _pending.removeWhere((key, value) => key == versionDir && identical(value, operation));
    });
    _pending[versionDir] = operation;
    return operation;
  }

  Future<String> _installLocked(
    String versionDir, {
    required bool force,
    required ProvisionLog log,
    FfmpegAsset? asset,
  }) async {
    await Directory(p.dirname(versionDir)).create(recursive: true);
    final lock = await File('$versionDir.lock').open(mode: FileMode.append);
    try {
      await _acquireProvisionLock(lock, '$versionDir.lock', lockTimeout, log);
      if (!force &&
          isInstalled &&
          await _usable(_cache.binaryPath!) &&
          await _usable(_cache.probePath!)) {
        return _cache.binaryPath!;
      }
      final release = asset ?? ffmpegAssetFor(_cache.abi);
      if (release.archiveProbePath == null && release.probeAsset == null) {
        throw const CliFailure('The pinned release has no companion ffprobe archive.');
      }
      log('Downloading $pinnedFfmpegBuildLabel (FFmpeg and ffprobe) ...');
      final archive = await _download(release);
      final executables = extractFfmpegBinaries(
        archiveBytes: archive,
        format: release.format,
        innerPaths: {
          release.archiveBinaryPath,
          if (release.archiveProbePath != null) release.archiveProbePath!,
        },
      );
      final probeAsset = release.probeAsset;
      final probe = probeAsset == null
          ? executables[release.archiveProbePath]!
          : extractFfmpegBinary(
              archiveBytes: await _download(probeAsset),
              format: probeAsset.format,
              innerPath: probeAsset.archiveBinaryPath,
            );
      final stage = await Directory(p.dirname(versionDir)).createTemp('.fluvie-install-');
      Directory? previous;
      try {
        final binDir = await Directory(p.join(stage.path, 'bin')).create();
        final ffmpeg = p.join(binDir.path, p.basename(_cache.binaryPath!));
        final ffprobe = p.join(binDir.path, p.basename(_cache.probePath!));
        log('Extracting and checking FFmpeg and ffprobe ...');
        await _writeExecutable(ffmpeg, executables[release.archiveBinaryPath]!);
        await _writeExecutable(ffprobe, probe);
        await _probe(ffmpeg);
        await _probe(ffprobe);
        await File(p.join(stage.path, 'toolchain.json')).writeAsString(
          jsonEncode({
            'build': _cache.version,
            'abi': _cache.abiLabel,
            'ffmpegArchive': release.url,
            'ffmpegArchiveSha256': release.sha256,
            'ffprobeArchive': probeAsset?.url ?? release.url,
            'ffprobeArchiveSha256': probeAsset?.sha256 ?? release.sha256,
          }),
        );
        final current = Directory(versionDir);
        if (current.existsSync()) {
          previous = await current.rename(
            '$versionDir.previous-${DateTime.now().microsecondsSinceEpoch}',
          );
        }
        try {
          await stage.rename(versionDir);
        } on Object {
          if (previous != null) await previous.rename(versionDir);
          previous = null;
          rethrow;
        }
        log('Installed FFmpeg and ffprobe at ${p.join(versionDir, 'bin')}');
        return _cache.binaryPath!;
      } finally {
        if (stage.existsSync()) await stage.delete(recursive: true);
        if (previous != null && previous.existsSync()) await previous.delete(recursive: true);
      }
    } on FileSystemException catch (error) {
      throw CliFailure('Could not install the FFmpeg toolchain: ${error.message} (${error.path}).');
    } finally {
      await lock.close();
    }
  }
}
