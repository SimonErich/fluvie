import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';

void main() {
  group('SnapshotRaster', () {
    test('carries bytes, content hash and pixel dimensions', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final raster = SnapshotRaster(
        bytes: bytes,
        contentHash: 'deadbeef',
        width: 16,
        height: 9,
      );
      expect(raster.bytes, same(bytes));
      expect(raster.contentHash, 'deadbeef');
      expect(raster.width, 16);
      expect(raster.height, 9);
    });

    test('is value-equal by content hash and dimensions', () {
      final a = SnapshotRaster(
        bytes: Uint8List.fromList([1, 2]),
        contentHash: 'abc',
        width: 4,
        height: 4,
      );
      final b = SnapshotRaster(
        bytes: Uint8List.fromList([9, 9]),
        contentHash: 'abc',
        width: 4,
        height: 4,
      );
      expect(a, b, reason: 'equality keys on the content hash, not the buffer identity');
      expect(a.hashCode, b.hashCode);
    });

    test('differs when the content hash differs', () {
      final a = SnapshotRaster(bytes: Uint8List(0), contentHash: 'a', width: 1, height: 1);
      final b = SnapshotRaster(bytes: Uint8List(0), contentHash: 'b', width: 1, height: 1);
      expect(a, isNot(b));
    });

    test('rejects non-positive dimensions', () {
      expect(
        () => SnapshotRaster(bytes: Uint8List(0), contentHash: 'a', width: 0, height: 1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toString names the dimensions and hash', () {
      final raster = SnapshotRaster(bytes: Uint8List(0), contentHash: 'xy', width: 8, height: 4);
      expect(raster.toString(), contains('8'));
      expect(raster.toString(), contains('4'));
      expect(raster.toString(), contains('xy'));
    });
  });
}
