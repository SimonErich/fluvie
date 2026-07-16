import 'dart:io' show Platform;

/// The base directory Fluvie keeps its user-level caches under
/// (`<base>/fluvie`), or `null` when the platform's base cannot be resolved
/// (no `HOME` / `LOCALAPPDATA`).
///
/// `$XDG_CACHE_HOME` (falling back to `~/.cache`) on Linux and macOS,
/// `%LOCALAPPDATA%` on Windows — the same layout `fluvie_cli`'s `FfmpegCache`
/// resolves its managed FFmpeg build under, deliberately duplicated rather than
/// imported: `fluvie` must not depend on `fluvie_cli` (the dependency points the
/// other way).
///
/// Pure path computation — no filesystem touch. [environment] and [windows]
/// default to the host's and exist so a test can resolve any platform's layout
/// hermetically. Callers must treat `null` as "run uncached": a cache must not
/// fall back to the system temp directory, which is exactly what it exists to
/// stop filling.
String? userCacheRoot({Map<String, String>? environment, bool? windows}) {
  final env = environment ?? Platform.environment;
  final onWindows = windows ?? Platform.isWindows;
  final base = onWindows ? _nonEmpty(env['LOCALAPPDATA']) : _posixBase(env);
  return base == null ? null : '$base/fluvie';
}

String? _posixBase(Map<String, String> env) {
  final xdg = _nonEmpty(env['XDG_CACHE_HOME']);
  if (xdg != null) return xdg;
  final home = _nonEmpty(env['HOME']);
  return home == null ? null : '$home/.cache';
}

String? _nonEmpty(String? value) => (value == null || value.isEmpty) ? null : value;
