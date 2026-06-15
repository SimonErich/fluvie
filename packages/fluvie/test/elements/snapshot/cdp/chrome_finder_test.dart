import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_snapshot_unavailable_error.dart';
import 'package:fluvie/src/elements/snapshot/cdp/chrome_finder.dart';

void main() {
  group('findChrome', () {
    test('returns the first probe path that exists', () {
      final path = findChrome(
        probePaths: const ['/no/chrome', '/opt/google/chrome/chrome', '/usr/bin/chromium'],
        exists: (p) => p == '/opt/google/chrome/chrome',
      );
      expect(path, '/opt/google/chrome/chrome');
    });

    test('honours the FLUVIE_CHROME env override before the probe paths', () {
      final path = findChrome(
        probePaths: const ['/opt/google/chrome/chrome'],
        env: const {'FLUVIE_CHROME': '/custom/chrome'},
        exists: (p) => true,
      );
      expect(path, '/custom/chrome');
    });

    test('throws FluvieSnapshotUnavailableError naming the fix when none exist', () {
      expect(
        () => findChrome(
          probePaths: const ['/a', '/b'],
          exists: (_) => false,
        ),
        throwsA(
          isA<FluvieSnapshotUnavailableError>()
              .having((e) => e.message, 'message', contains('Chrome'))
              .having((e) => e.installHint, 'installHint', isNotNull),
        ),
      );
    });

    test('throws when the env override points at a missing binary', () {
      expect(
        () => findChrome(
          probePaths: const [],
          env: const {'FLUVIE_CHROME': '/missing/chrome'},
          exists: (_) => false,
        ),
        throwsA(isA<FluvieSnapshotUnavailableError>()),
      );
    });

    test('ignores an empty env override and falls back to probe paths', () {
      final path = findChrome(
        probePaths: const ['/opt/google/chrome/chrome'],
        env: const {'FLUVIE_CHROME': ''},
        exists: (p) => p == '/opt/google/chrome/chrome',
      );
      expect(path, '/opt/google/chrome/chrome');
    });

    test('skips earlier non-existent paths and returns a later existing one', () {
      final path = findChrome(
        probePaths: const ['/a', '/b', '/c'],
        exists: (p) => p == '/c',
      );
      expect(path, '/c');
    });

    test('the default probe paths cover the common Linux binaries', () {
      expect(defaultChromeProbePaths, contains('/opt/google/chrome/chrome'));
      expect(defaultChromeProbePaths, contains('/usr/bin/chromium'));
    });
  });
}
