import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_snapshot_unavailable_error.dart';
import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';

/// The permanent gate default [SnapshotService] (decision D-FakeDefault): it
/// serves committed fixture PNGs instead of driving a browser, so the gate is
/// green without Chromium and without the live network, forever.
///
/// A request is matched first to an explicit per-request fixture, then by kind
/// (any mermaid, any html, any url) via the defaults. An unmatched request is a
/// [FluvieSnapshotUnavailableError] (the same typed failure the real service
/// raises for a missing capability), never a blank raster.
///
/// The fixtures it serves are deterministic solid/striped rasters standing in
/// for real diagram/page PNGs until those land with the widgets and goldens in
/// 12.2-12.4 (recorded deviation). Each raster's content hash is the FNV-1a-64
/// of its PNG bytes, and its pixel size is read from the PNG IHDR — no async
/// image decode, so dimensions are exact and deterministic.
class FakeSnapshotService implements SnapshotService {
  /// Creates a fake serving exactly the `fixtures` map (`request -> fixture
  /// file name`), with an optional `byKind` fallback (`kind -> fixture file
  /// name`) for the defaults; the explicit map wins.
  FakeSnapshotService(this._fixtures, {Map<Type, String> byKind = const {}})
    : _byKind = Map.of(byKind);

  /// The default fake: any mermaid, html or url request resolves to its
  /// committed fixture by kind.
  factory FakeSnapshotService.withDefaults() => FakeSnapshotService(
    const {},
    byKind: const {
      MermaidRequest: 'mermaid_flowchart.png',
      HtmlRequest: 'html_page.png',
      UrlRequest: 'webpage.png',
    },
  );

  final Map<SnapshotRequest, String> _fixtures;
  final Map<Type, String> _byKind;

  /// The directory the committed fixture PNGs live in, relative to the package
  /// root (where `flutter test` runs).
  static const fixturesDir = 'test/elements/snapshot/fixtures';

  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async {
    final name = _fixtures[request] ?? _byKind[request.runtimeType];
    if (name == null) {
      throw FluvieSnapshotUnavailableError(
        'No fixture mapped for $request. Map it explicitly or use '
        'FakeSnapshotService.withDefaults().',
        installHint: 'add a fixture PNG and map the request in the fake',
      );
    }
    final bytes = await File('$fixturesDir/$name').readAsBytes();
    final (width, height) = _pngSize(bytes, name);
    return SnapshotRaster(
      bytes: bytes,
      contentHash: fnv1a64Hex(bytes),
      width: width,
      height: height,
    );
  }

  /// Reads the pixel dimensions from a PNG's IHDR chunk (big-endian width at
  /// byte 16, height at byte 20) — deterministic and decode-free.
  (int, int) _pngSize(Uint8List bytes, String name) {
    if (bytes.length < 24) {
      throw FluvieSnapshotUnavailableError('Fixture "$name" is not a valid PNG.');
    }
    final data = ByteData.sublistView(bytes);
    return (data.getUint32(16), data.getUint32(20));
  }
}
