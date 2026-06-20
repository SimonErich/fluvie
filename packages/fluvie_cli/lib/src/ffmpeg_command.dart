import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:fluvie_cli/src/process_runner.dart';

const List<String> _actions = ['install', 'path', 'status', 'uninstall'];

/// `fluvie ffmpeg <install|path|status|uninstall>`: manage the FFmpeg build
/// Fluvie downloads and caches so renders work without a system FFmpeg.
///
/// `install` downloads, checksum-verifies and caches the pinned build (renders
/// also do this on demand). `path` prints where the managed binary lives,
/// `status` reports the pinned build and whether it is installed, and
/// `uninstall` removes it.
final class FfmpegCommand {
  /// Creates the command; the runner, cache and installer are injectable.
  FfmpegCommand({
    this._runner = const IoProcessRunner(),
    FfmpegCache? cache,
    this._installer,
  }) : _cache = cache ?? FfmpegCache();

  final ProcessRunner _runner;
  final FfmpegCache _cache;
  final FfmpegInstaller? _installer;

  FfmpegInstaller get _resolvedInstaller =>
      _installer ?? FfmpegProvisioner(runner: _runner, cache: _cache);

  /// The `ffmpeg` command's argument parser.
  static ArgParser buildParser() =>
      ArgParser()
        ..addFlag('force', negatable: false, help: 'Re-download even if already installed.');

  /// Runs the requested action; returns the process exit code.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 1 || !_actions.contains(args.rest.single)) {
      final given = args.rest.isEmpty ? '(none)' : args.rest.join(' ');
      err.writeln(
        'Unknown ffmpeg action "$given". Usage: fluvie ffmpeg <${_actions.join('|')}>',
      );
      return 64;
    }
    return switch (args.rest.single) {
      'install' => _install(force: args.flag('force'), out: out, err: err),
      'path' => _path(out: out, err: err),
      'status' => _status(out: out, err: err),
      _ => _uninstall(out: out, err: err),
    };
  }

  Future<int> _install({
    required bool force,
    required StringSink out,
    required StringSink err,
  }) async {
    try {
      final path = await _resolvedInstaller.install(force: force, log: out.writeln);
      out.writeln('FFmpeg ready: $path');
      return 0;
    } on CliFailure catch (failure) {
      err.writeln(failure.message);
      return 1;
    }
  }

  int _path({required StringSink out, required StringSink err}) {
    final path = _cache.binaryPath;
    if (path == null) {
      err.writeln('Could not resolve a cache directory for the managed FFmpeg build.');
      return 1;
    }
    out.writeln(path);
    return 0;
  }

  Future<int> _status({required StringSink out, required StringSink err}) async {
    out.writeln('Pinned build: $pinnedFfmpegBuildLabel');
    final path = _cache.binaryPath;
    if (path == null) {
      out.writeln('Managed cache: unavailable (no cache directory on this platform).');
      return 0;
    }
    out.writeln('Managed path: $path');
    if (!File(path).existsSync()) {
      out.writeln('Status: not installed (run `fluvie ffmpeg install`).');
      return 0;
    }
    final banner = await _versionBanner(path);
    out
      ..writeln('Status: installed.')
      ..writeln('Version: $banner');
    return 0;
  }

  Future<String> _versionBanner(String path) async {
    try {
      final result = await _runner.run(path, const ['-version']);
      final firstLine = result.stdout.split('\n').first.trim();
      return firstLine.isEmpty ? '(present, but reported no version)' : firstLine;
    } on ProcessException {
      return '(present, but failed to run)';
    }
  }

  Future<int> _uninstall({required StringSink out, required StringSink err}) async {
    final dir = _cache.versionDir;
    if (dir == null || !Directory(dir).existsSync()) {
      out.writeln('Nothing to remove (no managed FFmpeg is installed).');
      return 0;
    }
    await Directory(dir).delete(recursive: true);
    out.writeln('Removed the managed FFmpeg build at $dir.');
    return 0;
  }
}
