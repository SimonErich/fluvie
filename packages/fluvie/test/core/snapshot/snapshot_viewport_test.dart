import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';

void main() {
  group('SnapshotViewport', () {
    test('carries width, height and defaults deviceScale to 1.0', () {
      const viewport = SnapshotViewport(width: 800, height: 600);
      expect(viewport.width, 800);
      expect(viewport.height, 600);
      expect(viewport.deviceScale, 1.0);
    });

    test('carries an explicit deviceScale', () {
      const viewport = SnapshotViewport(width: 400, height: 300, deviceScale: 2);
      expect(viewport.deviceScale, 2.0);
    });

    test('is value-equal across identical fields', () {
      expect(
        const SnapshotViewport(width: 800, height: 600),
        const SnapshotViewport(width: 800, height: 600),
      );
      expect(
        const SnapshotViewport(width: 800, height: 600).hashCode,
        const SnapshotViewport(width: 800, height: 600).hashCode,
      );
    });

    test('differs when any field differs', () {
      const base = SnapshotViewport(width: 800, height: 600);
      expect(base, isNot(const SnapshotViewport(width: 801, height: 600)));
      expect(base, isNot(const SnapshotViewport(width: 800, height: 601)));
      expect(base, isNot(const SnapshotViewport(width: 800, height: 600, deviceScale: 2)));
    });

    test('rejects a non-positive width', () {
      expect(
        () => SnapshotViewport(width: 0, height: 100),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a non-positive height', () {
      expect(
        () => SnapshotViewport(width: 100, height: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a non-positive deviceScale', () {
      expect(
        () => SnapshotViewport(width: 100, height: 100, deviceScale: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('pixel dimensions scale by deviceScale, rounded', () {
      const viewport = SnapshotViewport(width: 400, height: 300, deviceScale: 2);
      expect(viewport.pixelWidth, 800);
      expect(viewport.pixelHeight, 600);
    });

    test('toString names the dimensions', () {
      expect(const SnapshotViewport(width: 800, height: 600).toString(), contains('800'));
      expect(const SnapshotViewport(width: 800, height: 600).toString(), contains('600'));
    });
  });
}
