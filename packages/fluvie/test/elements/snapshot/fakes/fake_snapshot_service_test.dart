import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_snapshot_unavailable_error.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';

import 'fake_snapshot_service.dart';

void main() {
  const viewport = SnapshotViewport(width: 800, height: 600);

  group('FakeSnapshotService', () {
    test('rasterizes a mapped request to its fixture raster', () async {
      final service = FakeSnapshotService({
        const SnapshotRequest.mermaid('graph TD; A-->B'): 'mermaid_flowchart.png',
      });

      final raster = await service.rasterize(const SnapshotRequest.mermaid('graph TD; A-->B'));

      expect(raster, isA<SnapshotRaster>());
      expect(raster.width, 32);
      expect(raster.height, 24);
      expect(raster.bytes, isNotEmpty);
      expect(raster.contentHash, isNotEmpty);
    });

    test('produces a stable content hash for the same fixture', () async {
      final service = FakeSnapshotService({
        const SnapshotRequest.mermaid('g'): 'mermaid_flowchart.png',
      });

      final a = await service.rasterize(const SnapshotRequest.mermaid('g'));
      final b = await service.rasterize(const SnapshotRequest.mermaid('g'));

      expect(a.contentHash, b.contentHash);
    });

    test('an unmapped request throws FluvieSnapshotUnavailableError', () {
      final service = FakeSnapshotService(const {});

      expect(
        () => service.rasterize(const SnapshotRequest.html('<p/>', viewport: viewport)),
        throwsA(
          isA<FluvieSnapshotUnavailableError>().having(
            (e) => e.message,
            'message',
            contains('No fixture'),
          ),
        ),
      );
    });

    test('serves the default fixtures map without explicit wiring', () async {
      final service = FakeSnapshotService.withDefaults();
      final raster = await service.rasterize(
        const SnapshotRequest.mermaid('graph TD; Start-->Stop'),
      );
      expect(raster.width, greaterThan(0));
    });
  });
}
