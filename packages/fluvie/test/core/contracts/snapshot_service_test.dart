import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_snapshot_unavailable_error.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';

/// An inline fake satisfying the contract, exercised by the tests below.
class _InlineSnapshotService implements SnapshotService {
  _InlineSnapshotService({this.available = true});

  final bool available;

  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async {
    if (!available) {
      throw FluvieSnapshotUnavailableError(
        'No snapshot backend available for $request.',
        installHint: 'install Chromium',
      );
    }
    return SnapshotRaster(
      bytes: Uint8List.fromList([0, 0, 0, 255]),
      contentHash: 'inline',
      width: 1,
      height: 1,
    );
  }
}

void main() {
  group('SnapshotService contract', () {
    test('rasterize returns a SnapshotRaster', () async {
      final service = _InlineSnapshotService();
      final raster = await service.rasterize(const SnapshotRequest.mermaid('graph TD; A-->B'));
      expect(raster, isA<SnapshotRaster>());
      expect(raster.width, 1);
    });

    test('a fake satisfies the interface', () {
      expect(_InlineSnapshotService(), isA<SnapshotService>());
    });

    test('rasterize is async (its result is a Future)', () {
      final service = _InlineSnapshotService();
      expect(
        service.rasterize(const SnapshotRequest.html('<p/>', viewport: _vp)),
        isA<Future<SnapshotRaster>>(),
      );
    });

    test('a missing-platform service surfaces FluvieSnapshotUnavailableError', () {
      final service = _InlineSnapshotService(available: false);
      expect(
        () => service.rasterize(const SnapshotRequest.mermaid('g')),
        throwsA(isA<FluvieSnapshotUnavailableError>()),
      );
    });
  });
}

const _vp = SnapshotViewport(width: 100, height: 100);
