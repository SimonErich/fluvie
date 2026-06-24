import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';

import 'harness_snapshot.dart';

void main() {
  group('prepareSnapshotMedia', () {
    test('returns null for a snapshot-less composition', () async {
      final resolver = await prepareSnapshotMedia(const <SnapshotSource>{});
      expect(resolver, isNull);
    });

    test('pre-resolves declared snapshots so paint reads them synchronously', () async {
      const source = SnapshotSource.mermaid('graph TD; A-->B');
      final resolver = await prepareSnapshotMedia({source});

      expect(resolver, isA<MediaResolver>());
      // A decoded image is available synchronously after the pre-pass.
      expect(resolver!.decodedSnapshotFor(source).width, greaterThan(0));
    });

    test('is offline-deterministic: the fixture raster needs no browser', () async {
      const source = SnapshotSource.html(
        '<p>hi</p>',
        viewport: SnapshotViewport(width: 64, height: 48),
      );
      final resolver = await prepareSnapshotMedia({source});
      expect(resolver!.decodedSnapshotFor(source).height, greaterThan(0));
    });
  });
}
