import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:path/path.dart' as p;

/// Resolves where Fluvie keeps its managed FFmpeg build.
///
/// Pure path computation — no filesystem touch — so it is fully unit-testable
/// for any target by injecting `abi` and `environment`. Existence checks and
/// writes live in the provisioner. The layout is
/// `<cacheRoot>/fluvie/ffmpeg/<version>/ffmpeg` (`ffmpeg.exe` on Windows),
/// where the cache root is `$XDG_CACHE_HOME` (or `~/.cache`) on Linux/macOS and
/// `%LOCALAPPDATA%` on Windows. Every accessor is `null` when the platform's
/// base directory cannot be resolved (no `HOME` / `LOCALAPPDATA`).
final class FfmpegCache {
  /// Creates a cache resolver for [abi] (default: the host) and [environment]
  /// (default: the process environment), keyed under the [version] subfolder.
  FfmpegCache({Map<String, String>? environment, Abi? abi, this.version = pinnedFfmpegVersion})
    : _env = environment ?? Platform.environment,
      _abi = abi ?? Abi.current();

  final Map<String, String> _env;
  final Abi _abi;

  /// The version label used as the cache subdirectory.
  final String version;

  bool get _isWindows => switch (_abi) {
    Abi.windowsArm64 || Abi.windowsIA32 || Abi.windowsX64 => true,
    _ => false,
  };

  /// The path context for the target OS, so a Windows target yields backslash
  /// paths even when the unit test runs on a POSIX host.
  p.Context get _ctx => _isWindows ? p.windows : p.posix;

  String? get _baseDir {
    if (_isWindows) {
      final localAppData = _env['LOCALAPPDATA'];
      return (localAppData == null || localAppData.isEmpty) ? null : localAppData;
    }
    final xdg = _env['XDG_CACHE_HOME'];
    if (xdg != null && xdg.isNotEmpty) return xdg;
    final home = _env['HOME'];
    if (home == null || home.isEmpty) return null;
    return _ctx.join(home, '.cache');
  }

  /// The directory holding every Fluvie-managed FFmpeg version
  /// (`<base>/fluvie/ffmpeg`), or `null` when the base cannot be resolved.
  String? get rootDir {
    final base = _baseDir;
    return base == null ? null : _ctx.join(base, 'fluvie', 'ffmpeg');
  }

  /// The directory holding the pinned build (`<rootDir>/<version>`).
  String? get versionDir {
    final root = rootDir;
    return root == null ? null : _ctx.join(root, version);
  }

  /// The managed FFmpeg binary path (`ffmpeg`, or `ffmpeg.exe` on Windows).
  String? get binaryPath {
    final dir = versionDir;
    if (dir == null) return null;
    return _ctx.join(dir, _isWindows ? 'ffmpeg.exe' : 'ffmpeg');
  }
}
