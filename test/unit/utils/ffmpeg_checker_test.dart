import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/utils/ffmpeg_checker.dart';

void main() {
  group('FFmpegDiagnostics', () {
    group('constructor', () {
      test('creates with required fields', () {
        const diagnostics = FFmpegDiagnostics(
          isAvailable: true,
          providerName: 'TestProvider',
        );

        expect(diagnostics.isAvailable, isTrue);
        expect(diagnostics.providerName, 'TestProvider');
        expect(diagnostics.version, isNull);
        expect(diagnostics.errorMessage, isNull);
        expect(diagnostics.installationInstructions, isNull);
      });

      test('creates with all fields', () {
        const diagnostics = FFmpegDiagnostics(
          isAvailable: false,
          providerName: 'TestProvider',
          version: '5.0.0',
          errorMessage: 'Not found',
          installationInstructions: 'Install FFmpeg',
        );

        expect(diagnostics.isAvailable, isFalse);
        expect(diagnostics.providerName, 'TestProvider');
        expect(diagnostics.version, '5.0.0');
        expect(diagnostics.errorMessage, 'Not found');
        expect(diagnostics.installationInstructions, 'Install FFmpeg');
      });
    });

    group('toString', () {
      test('returns available message when available', () {
        const diagnostics = FFmpegDiagnostics(
          isAvailable: true,
          providerName: 'FFmpegCli',
        );

        expect(diagnostics.toString(), contains('FFmpeg is available'));
        expect(diagnostics.toString(), contains('FFmpegCli'));
      });

      test('includes version when available', () {
        const diagnostics = FFmpegDiagnostics(
          isAvailable: true,
          providerName: 'FFmpegCli',
          version: '5.1.0',
        );

        expect(diagnostics.toString(), contains('5.1.0'));
      });

      test('returns not available message when unavailable', () {
        const diagnostics = FFmpegDiagnostics(
          isAvailable: false,
          providerName: 'FFmpegCli',
          errorMessage: 'FFmpeg not found',
        );

        expect(diagnostics.toString(), contains('NOT available'));
        expect(diagnostics.toString(), contains('FFmpeg not found'));
      });

      test('shows unknown error when no error message', () {
        const diagnostics = FFmpegDiagnostics(
          isAvailable: false,
          providerName: 'FFmpegCli',
        );

        expect(diagnostics.toString(), contains('Unknown error'));
      });
    });
  });

  group('FFmpegChecker', () {
    group('check', () {
      test('returns FFmpegDiagnostics', () async {
        final diagnostics = await FFmpegChecker.check();

        expect(diagnostics, isA<FFmpegDiagnostics>());
        expect(diagnostics.providerName, isNotEmpty);
      });

      test('diagnostics has valid provider name', () async {
        final diagnostics = await FFmpegChecker.check();

        expect(diagnostics.providerName, isA<String>());
        expect(diagnostics.providerName, isNotEmpty);
      });

      test('returns consistent results', () async {
        final diagnostics1 = await FFmpegChecker.check();
        final diagnostics2 = await FFmpegChecker.check();

        expect(diagnostics1.isAvailable, equals(diagnostics2.isAvailable));
        expect(diagnostics1.providerName, equals(diagnostics2.providerName));
      });

      test('includes installation instructions when not available', () async {
        final diagnostics = await FFmpegChecker.check();

        if (!diagnostics.isAvailable) {
          expect(diagnostics.installationInstructions, isNotNull);
          expect(diagnostics.installationInstructions, isNotEmpty);
        }
      });
    });

    group('isAvailable', () {
      test('returns a boolean', () async {
        final result = await FFmpegChecker.isAvailable();
        expect(result, isA<bool>());
      });

      test('returns consistent results', () async {
        final result1 = await FFmpegChecker.isAvailable();
        final result2 = await FFmpegChecker.isAvailable();

        expect(result1, equals(result2));
      });

      test('matches check result', () async {
        final isAvailable = await FFmpegChecker.isAvailable();
        final diagnostics = await FFmpegChecker.check();

        expect(isAvailable, equals(diagnostics.isAvailable));
      });
    });

    group('installation instructions', () {
      test('mentions Linux installation', () async {
        final diagnostics = await FFmpegChecker.check();

        if (diagnostics.installationInstructions != null) {
          expect(
            diagnostics.installationInstructions!.toLowerCase(),
            contains('linux'),
          );
        }
      });

      test('mentions macOS installation', () async {
        final diagnostics = await FFmpegChecker.check();

        if (diagnostics.installationInstructions != null) {
          expect(
            diagnostics.installationInstructions!.toLowerCase(),
            contains('macos'),
          );
        }
      });

      test('mentions Windows installation', () async {
        final diagnostics = await FFmpegChecker.check();

        if (diagnostics.installationInstructions != null) {
          expect(
            diagnostics.installationInstructions!.toLowerCase(),
            contains('windows'),
          );
        }
      });

      test('mentions Web CORS requirements', () async {
        final diagnostics = await FFmpegChecker.check();

        if (diagnostics.installationInstructions != null) {
          expect(
            diagnostics.installationInstructions!.toLowerCase(),
            contains('web'),
          );
        }
      });
    });
  });
}
