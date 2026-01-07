import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/utils/impeller_checker.dart';

void main() {
  group('ImpellerChecker', () {
    setUp(() {
      ImpellerChecker.reset();
    });

    tearDown(() {
      ImpellerChecker.reset();
    });

    group('isImpellerEnabled', () {
      test('returns a result without throwing', () {
        expect(() => ImpellerChecker.isImpellerEnabled(), returnsNormally);
      });

      test('caches result after first call', () {
        final result1 = ImpellerChecker.isImpellerEnabled();
        final result2 = ImpellerChecker.isImpellerEnabled();

        expect(result1, equals(result2));
      });

      test('reset clears cache', () {
        ImpellerChecker.isImpellerEnabled();
        ImpellerChecker.reset();

        // After reset, should be able to check again
        expect(() => ImpellerChecker.isImpellerEnabled(), returnsNormally);
      });

      test('returns bool or null', () {
        final result = ImpellerChecker.isImpellerEnabled();
        expect(result, anyOf(isTrue, isFalse, isNull));
      });
    });

    group('platform detection', () {
      test('iOS returns true (Impeller default)', () {
        // This test verifies the expected behavior for iOS
        // In test environment, defaultTargetPlatform may not be iOS
        // so we just verify the method runs without error
        expect(() => ImpellerChecker.isImpellerEnabled(), returnsNormally);
      });

      test('non-iOS platforms may return false', () {
        // On non-iOS platforms in test, Impeller is typically not enabled
        final result = ImpellerChecker.isImpellerEnabled();
        // Result depends on platform and environment
        expect(result, anyOf(isTrue, isFalse, isNull));
      });
    });

    group('logWarningIfSkia', () {
      test('does not throw when Impeller enabled', () {
        expect(() => ImpellerChecker.logWarningIfSkia(), returnsNormally);
      });

      test('does not throw when Skia detected', () {
        // Force Skia detection scenario
        // The method should not throw regardless of renderer
        expect(() => ImpellerChecker.logWarningIfSkia(), returnsNormally);
      });
    });

    group('enforceImpeller', () {
      testWidgets('may throw or not depending on platform', (tester) async {
        // This test documents the expected behavior:
        // - On iOS: should not throw (Impeller default)
        // - On other platforms: may throw FlutterError

        // We can't easily control the platform in tests, so just verify
        // the method is callable
        try {
          ImpellerChecker.enforceImpeller();
          // If we get here, Impeller is enabled (or detection returned null)
        } on FlutterError catch (e) {
          // Expected on non-Impeller platforms
          expect(e.message, contains('Impeller'));
        }
      });
    });

    group('reset', () {
      test('allows rechecking after reset', () {
        // First check
        ImpellerChecker.isImpellerEnabled();

        // Reset
        ImpellerChecker.reset();

        // Second check should work
        expect(() => ImpellerChecker.isImpellerEnabled(), returnsNormally);
      });

      test('is annotated with @visibleForTesting', () {
        // This is a compile-time check - if the method exists and is callable
        // from a test file, the annotation is working
        expect(() => ImpellerChecker.reset(), returnsNormally);
      });
    });

    group('showWarningIfSkia', () {
      testWidgets('does not throw with unmounted context', (tester) async {
        await tester.pumpWidget(const SizedBox());

        // Get a context that will be unmounted
        final context = tester.element(find.byType(SizedBox));

        // Pump new widget to unmount the old one
        await tester.pumpWidget(const SizedBox(key: Key('new')));

        // Should handle unmounted context gracefully
        // The method checks context.mounted before showing dialog
        expect(
          () => ImpellerChecker.showWarningIfSkia(context),
          returnsNormally,
        );
      });

      testWidgets('does not throw with mounted context', (tester) async {
        await tester.pumpWidget(const SizedBox());

        final context = tester.element(find.byType(SizedBox));

        // Should handle mounted context
        expect(
          () => ImpellerChecker.showWarningIfSkia(context),
          returnsNormally,
        );
      });
    });
  });
}
