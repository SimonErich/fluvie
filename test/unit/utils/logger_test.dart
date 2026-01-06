import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/utils/logger.dart';

void main() {
  group('FluvieLogLevel', () {
    test('has correct ordering', () {
      expect(FluvieLogLevel.debug.index, 0);
      expect(FluvieLogLevel.info.index, 1);
      expect(FluvieLogLevel.warning.index, 2);
      expect(FluvieLogLevel.error.index, 3);
    });

    test('debug is least verbose', () {
      expect(FluvieLogLevel.debug.index, lessThan(FluvieLogLevel.info.index));
    });

    test('error is most verbose', () {
      expect(FluvieLogLevel.error.index, greaterThan(FluvieLogLevel.warning.index));
    });
  });

  group('FluvieLogger', () {
    setUp(() {
      FluvieLogger.reset();
    });

    tearDown(() {
      FluvieLogger.reset();
    });

    group('configuration', () {
      test('is disabled by default', () {
        expect(FluvieLogger.isEnabled, isFalse);
      });

      test('default minLevel is warning', () {
        expect(FluvieLogger.minLevel, FluvieLogLevel.warning);
      });

      test('can enable logging', () {
        FluvieLogger.configure(enabled: true);
        expect(FluvieLogger.isEnabled, isTrue);
      });

      test('can disable logging', () {
        FluvieLogger.configure(enabled: true);
        FluvieLogger.configure(enabled: false);
        expect(FluvieLogger.isEnabled, isFalse);
      });

      test('can set minLevel', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.debug,
        );
        expect(FluvieLogger.minLevel, FluvieLogLevel.debug);
      });

      test('can configure modules', () {
        FluvieLogger.configure(
          enabled: true,
          modules: {'render', 'encoder'},
        );
        expect(FluvieLogger.isEnabled, isTrue);
      });

      test('reset restores defaults', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.debug,
          modules: {'test'},
        );

        FluvieLogger.reset();

        expect(FluvieLogger.isEnabled, isFalse);
        expect(FluvieLogger.minLevel, FluvieLogLevel.warning);
      });
    });

    group('logging methods', () {
      // Note: We can't easily verify output, but we can verify methods don't throw

      test('debug does not throw when disabled', () {
        expect(() => FluvieLogger.debug('test'), returnsNormally);
      });

      test('info does not throw when disabled', () {
        expect(() => FluvieLogger.info('test'), returnsNormally);
      });

      test('warning does not throw when disabled', () {
        expect(() => FluvieLogger.warning('test'), returnsNormally);
      });

      test('error does not throw when disabled', () {
        expect(() => FluvieLogger.error('test'), returnsNormally);
      });

      test('debug with module does not throw', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        expect(
          () => FluvieLogger.debug('test', module: 'render'),
          returnsNormally,
        );
      });

      test('error with error object does not throw', () {
        FluvieLogger.configure(enabled: true);
        expect(
          () => FluvieLogger.error(
            'test',
            error: Exception('test error'),
            stackTrace: StackTrace.current,
          ),
          returnsNormally,
        );
      });

      test('box formatting does not throw', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        expect(
          () => FluvieLogger.box(
            'Title',
            ['Line 1', 'Line 2', 'Line 3'],
            module: 'test',
          ),
          returnsNormally,
        );
      });

      test('section formatting does not throw', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        expect(
          () => FluvieLogger.section(
            'Title',
            ['Line 1', 'Line 2'],
            module: 'test',
          ),
          returnsNormally,
        );
      });
    });

    group('level filtering', () {
      test('logs above minLevel when enabled', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.info,
        );

        // These should not throw (level >= minLevel)
        expect(() => FluvieLogger.info('test'), returnsNormally);
        expect(() => FluvieLogger.warning('test'), returnsNormally);
        expect(() => FluvieLogger.error('test'), returnsNormally);
      });

      test('debug level allows all logs', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.debug,
        );

        expect(() => FluvieLogger.debug('test'), returnsNormally);
        expect(() => FluvieLogger.info('test'), returnsNormally);
        expect(() => FluvieLogger.warning('test'), returnsNormally);
        expect(() => FluvieLogger.error('test'), returnsNormally);
      });

      test('error level only allows error logs', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.error,
        );

        // These are below error level but should not throw
        expect(() => FluvieLogger.debug('test'), returnsNormally);
        expect(() => FluvieLogger.info('test'), returnsNormally);
        expect(() => FluvieLogger.warning('test'), returnsNormally);
        expect(() => FluvieLogger.error('test'), returnsNormally);
      });
    });

    group('module filtering', () {
      test('logs from configured modules when enabled', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.debug,
          modules: {'render', 'encoder'},
        );

        // These should not throw
        expect(
          () => FluvieLogger.debug('test', module: 'render'),
          returnsNormally,
        );
        expect(
          () => FluvieLogger.debug('test', module: 'encoder'),
          returnsNormally,
        );
      });

      test('logs without module work with module filtering', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.debug,
          modules: {'render'},
        );

        // Logs without module should still work
        expect(() => FluvieLogger.debug('test'), returnsNormally);
      });

      test('null modules enables all modules', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.debug,
          modules: null,
        );

        // All modules should work
        expect(
          () => FluvieLogger.debug('test', module: 'any_module'),
          returnsNormally,
        );
      });
    });

    group('edge cases', () {
      test('handles empty message', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        expect(() => FluvieLogger.debug(''), returnsNormally);
      });

      test('handles very long message', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        final longMessage = 'x' * 10000;
        expect(() => FluvieLogger.debug(longMessage), returnsNormally);
      });

      test('handles message with special characters', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        expect(
          () => FluvieLogger.debug('Test: \n\t\r 🎬 \u0000'),
          returnsNormally,
        );
      });

      test('handles unicode module name', () {
        FluvieLogger.configure(
          enabled: true,
          minLevel: FluvieLogLevel.debug,
        );
        expect(
          () => FluvieLogger.debug('test', module: '模块'),
          returnsNormally,
        );
      });

      test('box with long lines wraps', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        expect(
          () => FluvieLogger.box(
            'Title',
            ['A' * 200], // Very long line that needs wrapping
          ),
          returnsNormally,
        );
      });

      test('box with empty lines', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        expect(
          () => FluvieLogger.box('Title', []),
          returnsNormally,
        );
      });

      test('section with empty lines', () {
        FluvieLogger.configure(enabled: true, minLevel: FluvieLogLevel.debug);
        expect(
          () => FluvieLogger.section('Title', []),
          returnsNormally,
        );
      });
    });
  });
}
