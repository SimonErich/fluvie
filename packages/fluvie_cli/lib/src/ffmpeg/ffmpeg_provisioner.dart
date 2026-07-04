import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_archive_extractor.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_downloader.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:fluvie_cli/src/process_runner.dart';

/// A sink for human-readable provisioning progress lines.
typedef ProvisionLog = void Function(String message);

void _noLog(String _) {}

/// The provisioning seam the FFmpeg gate depends on: download-and-install the
/// pinned build, returning its path. An interface so the gate can be tested
/// without a network (the concrete [FfmpegProvisioner] is `final`).
// ignore: one_member_abstracts — the seam is the type; a function can't be injected the same way.
abstract interface class FfmpegInstaller {
  /// Installs the pinned build and returns the binary path. A present install
  /// is reused unless [force].
  Future<String> install({bool force, ProvisionLog log});
}

/// Downloads, verifies and installs Fluvie's pinned FFmpeg build into the
/// managed cache.
///
/// Every external seam — the downloader, the process runner (for `chmod` and
/// the post-install probe) and the cache location — is injectable, so the whole
/// install can be unit-tested without a network. Production wiring uses the
/// real HTTP downloader and the host cache.
final class FfmpegProvisioner implements FfmpegInstaller {
  /// Creates a provisioner. Defaults wire the real HTTP downloader, the host
  /// cache, and a real process runner.
  FfmpegProvisioner({
    this._runner = const IoProcessRunner(),
    FfmpegDownloader? downloader,
    FfmpegCache? cache,
  }) : _downloader = downloader ?? HttpFfmpegDownloader(),
       _cache = cache ?? FfmpegCache();

  final ProcessRunner _runner;
  final FfmpegDownloader _downloader;
  final FfmpegCache _cache;

  /// The managed binary path (whether or not it exists), or `null` when no
  /// cache directory can be resolved on this platform.
  String? get binaryPath => _cache.binaryPath;

  /// Whether the managed binary already exists on disk.
  bool get isInstalled {
    final path = _cache.binaryPath;
    return path != null && File(path).existsSync();
  }

  /// Installs the pinned build and returns the installed binary's path.
  ///
  /// A present install is returned untouched unless [force]. [asset] overrides
  /// the host's pinned asset (for tests). Throws a [CliFailure] on any failure,
  /// leaving no partial binary behind.
  @override
  Future<String> install({
    bool force = false,
    ProvisionLog log = _noLog,
    FfmpegAsset? asset,
  }) async {
    final binaryPath = _cache.binaryPath;
    final versionDir = _cache.versionDir;
    if (binaryPath == null || versionDir == null) {
      throw const CliFailure(
        'Could not resolve a cache directory for the managed FFmpeg build. Set '
        r'$XDG_CACHE_HOME or $HOME (or $LOCALAPPDATA on Windows), or install '
        r'FFmpeg yourself and point --ffmpeg / $FLUVIE_FFMPEG at it.',
      );
    }
    if (!force && File(binaryPath).existsSync()) return binaryPath;

    // coverage:ignore-line the host asset default is exercised by the download tagged provision test
    final resolved = asset ?? ffmpegAssetFor();
    log('Downloading $pinnedFfmpegBuildLabel ...');
    final bytes = await _downloader.download(resolved.url);
    _verify(bytes, resolved);

    log('Extracting ffmpeg ...');
    final binary = extractFfmpegBinary(
      archiveBytes: bytes,
      format: resolved.format,
      innerPath: resolved.archiveBinaryPath,
    );

    await _installBytes(binary, binaryPath, versionDir);
    await _probe(binaryPath);
    log('Installed FFmpeg at $binaryPath');
    return binaryPath;
  }

  void _verify(List<int> bytes, FfmpegAsset asset) {
    if (bytes.length != asset.sizeBytes) {
      throw CliFailure(
        'The downloaded FFmpeg archive is ${bytes.length} bytes but '
        '${asset.sizeBytes} were expected. Aborting (possible corruption).',
      );
    }
    final digest = sha256.convert(bytes).toString();
    if (digest != asset.sha256) {
      throw CliFailure(
        'The downloaded FFmpeg archive failed its SHA-256 checksum (expected '
        '${asset.sha256}, got $digest). Refusing to install it.',
      );
    }
  }

  /// Writes [binary] to a temp sibling, marks it executable, then atomically
  /// renames it into place — so a crash mid-write never leaves a half-written
  /// binary that the existence check would later trust.
  Future<void> _installBytes(List<int> binary, String binaryPath, String versionDir) async {
    await Directory(versionDir).create(recursive: true);
    final tmp = File('$binaryPath.tmp');
    try {
      await tmp.writeAsBytes(binary, flush: true);
      if (!Platform.isWindows) {
        final chmod = await _runner.run('chmod', ['+x', tmp.path]);
        if (chmod.exitCode != 0) {
          throw CliFailure(
            'Could not mark the FFmpeg binary executable (chmod exited '
            '${chmod.exitCode}).',
          );
        }
      }
      final existing = File(binaryPath);
      if (existing.existsSync()) await existing.delete();
      await tmp.rename(binaryPath);
    } on Object {
      if (tmp.existsSync()) await tmp.delete();
      rethrow;
    }
  }

  Future<void> _probe(String binaryPath) async {
    final result = await _runner.run(binaryPath, const ['-version']);
    if (result.exitCode != 0) {
      final file = File(binaryPath);
      if (file.existsSync()) await file.delete();
      throw CliFailure(
        'The provisioned FFmpeg at $binaryPath did not run (`-version` exited '
        '${result.exitCode}). The download may be incompatible with this machine.',
      );
    }
  }
}
