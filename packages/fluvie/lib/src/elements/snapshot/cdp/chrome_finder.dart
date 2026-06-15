import 'package:fluvie/src/core/errors/fluvie_snapshot_unavailable_error.dart';

/// Tests whether a binary exists at [path] — injected so the finder is unit
/// tested with no real filesystem and no real Chrome.
typedef BinaryExists = bool Function(String path);

/// The Chrome/Chromium binaries probed on a Linux host, in priority order.
/// The first one that exists wins.
const List<String> defaultChromeProbePaths = [
  '/opt/google/chrome/chrome',
  '/usr/bin/google-chrome-stable',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
  '/snap/bin/chromium',
];

/// Resolves the Chrome binary to drive the headless snapshot capture, or throws
/// a typed error naming the install fix.
///
/// The `FLUVIE_CHROME` entry in [env] wins when it names an existing binary;
/// otherwise the first existing path in [probePaths] (the
/// [defaultChromeProbePaths] by default) is used. When nothing resolves, a
/// [FluvieSnapshotUnavailableError] names the missing capability and the fix,
/// never a blank frame. [exists] is injected so this is a pure, fully-tested
/// function — the real call passes a `dart:io` `File.existsSync`-backed
/// predicate.
String findChrome({
  required BinaryExists exists,
  List<String> probePaths = defaultChromeProbePaths,
  Map<String, String> env = const {},
}) {
  final override = env['FLUVIE_CHROME'];
  if (override != null && override.isNotEmpty) {
    if (exists(override)) return override;
    throw FluvieSnapshotUnavailableError(
      'FLUVIE_CHROME points at "$override", but no binary exists there.',
      installHint: 'set FLUVIE_CHROME to a real Chrome/Chromium binary',
    );
  }
  for (final path in probePaths) {
    if (exists(path)) return path;
  }
  throw FluvieSnapshotUnavailableError(
    'No Chrome/Chromium binary found (probed: ${probePaths.join(', ')}). Live '
    'Mermaid/WebView/Html snapshots need a headless Chrome.',
    installHint:
        'install Chromium (for example "apt install chromium") or set '
        'FLUVIE_CHROME to a Chrome binary',
  );
}
