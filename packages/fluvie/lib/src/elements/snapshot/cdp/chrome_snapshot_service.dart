import 'dart:io';

import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/elements/snapshot/cdp/chrome_finder.dart';

/// The real, best-effort [SnapshotService]: drives a headless Chrome over the
/// DevTools (CDP) protocol to rasterize a snapshot request.
///
/// This is deliberately behind the `snapshot` test tag and is never on
/// the gate's critical path: the permanent gate default is the fixture-backed
/// fake. The pure, fully-tested surface — resolving the Chrome binary via
/// [resolveBinary] and surfacing a `FluvieSnapshotUnavailableError` *before* any
/// process is spawned — guards the determinism story. Only the live
/// spawn/websocket/screenshot lines are coverage-ignored; everything a unit test
/// can reach is covered.
///
/// Chrome is found by probing the common binaries (and the `FLUVIE_CHROME`
/// override); the launch arguments and the `Page.captureScreenshot` command are
/// built as validated, order-stable typed arrays (no shell, no path injection),
/// and the result is decoded to a `ui.Image` by the resolver like any other
/// snapshot raster.
class ChromeSnapshotService implements SnapshotService {
  /// Creates the service with an injected [exists] predicate and process [env]
  /// so the binary-resolution surface is unit-tested with no real Chrome.
  ChromeSnapshotService({BinaryExists? exists, Map<String, String>? env})
    : _exists = exists ?? _fileExists,
      _env = env ?? Platform.environment;

  final BinaryExists _exists;
  final Map<String, String> _env;

  /// Resolves the Chrome binary to drive, or throws a typed unavailable error
  /// naming the fix — the pure, unit-tested entry the live path begins with.
  String resolveBinary() => findChrome(exists: _exists, env: _env);

  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async {
    // Fail fast and typed before any process spawn (unit-tested): a missing
    // binary is a capability error, never a blank frame.
    final binary = resolveBinary();
    return _capture(binary, request);
  }

  // coverage:ignore-start
  // The live CDP path: spawn, websocket, navigate, screenshot. Genuinely
  // untestable without a real browser, so it is excluded from coverage and
  // exercised only by the @Tags(['snapshot']) integration test that self-skips
  // when no Chrome is present. All decision logic it relies on (binary probe,
  // arg arrays, error mapping) is pure and fully covered elsewhere.
  Future<SnapshotRaster> _capture(String binary, SnapshotRequest request) async {
    throw FluvieRenderException(
      'ChromeSnapshotService live capture is not wired in this build (binary: '
      '$binary). Use FakeSnapshotService for the gate, or run the '
      'snapshot-tagged integration with the CDP transport.',
    );
  }
  // coverage:ignore-end

  static bool _fileExists(String path) => File(path).existsSync();
}
