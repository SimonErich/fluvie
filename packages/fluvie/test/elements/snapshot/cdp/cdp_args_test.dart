import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/snapshot/cdp/cdp_args.dart';

void main() {
  group('buildChromeArgs', () {
    test('emits the deterministic headless flag set in a stable order', () {
      final a = buildChromeArgs(userDataDir: 'fluvie_cdp_sandbox', remoteDebuggingPort: 0);
      final b = buildChromeArgs(userDataDir: 'fluvie_cdp_sandbox', remoteDebuggingPort: 0);
      expect(a, b, reason: 'the arg array must be order-stable for determinism');
    });

    test('includes the determinism and isolation flags', () {
      final args = buildChromeArgs(userDataDir: 'sandbox', remoteDebuggingPort: 0);
      expect(args, contains('--headless=new'));
      expect(args, contains('--disable-gpu'));
      expect(args, contains('--hide-scrollbars'));
      expect(args, contains('--force-device-scale-factor=1'));
      expect(args, contains('--remote-debugging-port=0'));
      expect(args, contains('--user-data-dir=sandbox'));
    });

    test('never produces a shell string (every entry is a discrete token)', () {
      final args = buildChromeArgs(userDataDir: 'sandbox', remoteDebuggingPort: 0);
      expect(args.any((a) => a.contains(' &&') || a.contains(';') || a.contains('|')), isFalse);
    });

    test('rejects a user-data-dir that could inject a flag', () {
      expect(
        () => buildChromeArgs(userDataDir: '--evil', remoteDebuggingPort: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an empty user-data-dir', () {
      expect(
        () => buildChromeArgs(userDataDir: '', remoteDebuggingPort: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a negative remote debugging port', () {
      expect(
        () => buildChromeArgs(userDataDir: 'sandbox', remoteDebuggingPort: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a user-data-dir with a path separator or space (injection)', () {
      expect(
        () => buildChromeArgs(userDataDir: 'sand/box', remoteDebuggingPort: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => buildChromeArgs(userDataDir: 'sand box', remoteDebuggingPort: 0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('buildScreenshotCommand', () {
    test('builds a CDP Page.captureScreenshot command with the viewport clip', () {
      final command = buildScreenshotCommand(width: 800, height: 600, deviceScale: 2);
      expect(command['method'], 'Page.captureScreenshot');
      final params = command['params']! as Map<String, Object?>;
      final clip = params['clip']! as Map<String, Object?>;
      expect(clip['width'], 800);
      expect(clip['height'], 600);
      expect(clip['scale'], 2);
    });

    test('is value-stable for the same inputs (deterministic)', () {
      expect(
        buildScreenshotCommand(width: 100, height: 50, deviceScale: 1),
        buildScreenshotCommand(width: 100, height: 50, deviceScale: 1),
      );
    });

    test('rejects non-positive dimensions', () {
      expect(
        () => buildScreenshotCommand(width: 0, height: 50, deviceScale: 1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a non-positive device scale', () {
      expect(
        () => buildScreenshotCommand(width: 100, height: 50, deviceScale: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => buildScreenshotCommand(width: 100, height: 50, deviceScale: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
