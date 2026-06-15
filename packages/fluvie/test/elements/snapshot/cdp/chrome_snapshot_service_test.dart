import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_snapshot_unavailable_error.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/elements/snapshot/cdp/chrome_snapshot_service.dart';

void main() {
  group('ChromeSnapshotService (pure surface, no live browser)', () {
    test('resolveBinary returns the probed Chrome path', () {
      final service = ChromeSnapshotService(
        exists: (p) => p == '/opt/google/chrome/chrome',
        env: const {},
      );
      expect(service.resolveBinary(), '/opt/google/chrome/chrome');
    });

    test('resolveBinary honours the env override', () {
      final service = ChromeSnapshotService(
        exists: (_) => true,
        env: const {'FLUVIE_CHROME': '/custom/chrome'},
      );
      expect(service.resolveBinary(), '/custom/chrome');
    });

    test('resolveBinary throws FluvieSnapshotUnavailableError when none exist', () {
      final service = ChromeSnapshotService(exists: (_) => false, env: const {});
      expect(
        service.resolveBinary,
        throwsA(
          isA<FluvieSnapshotUnavailableError>().having(
            (e) => e.installHint,
            'installHint',
            isNotNull,
          ),
        ),
      );
    });

    test('rasterize surfaces the missing-Chrome error before any spawn', () {
      final service = ChromeSnapshotService(exists: (_) => false, env: const {});
      expect(
        () => service.rasterize(const SnapshotRequest.mermaid('graph TD; A-->B')),
        throwsA(isA<FluvieSnapshotUnavailableError>()),
      );
    });
  });
}
