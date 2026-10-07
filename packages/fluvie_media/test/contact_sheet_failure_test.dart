import 'dart:io';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

import 'fakes/session_fixture.dart';

void main() {
  final source = Uri.file('/fixture/cat.mp4');

  test('invalid contact-sheet geometry and sample budgets fail before probing', () async {
    var calls = 0;
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) async {
        calls++;
        return (exitCode: 0, stdout: '{}', stderr: '');
      },
    );
    addTearDown(tools.closeAsync);
    for (final samples in [0, 25]) {
      await expectLater(
        tools.contactSheet(source, outputPath: '/unused', samples: samples),
        throwsArgumentError,
      );
    }
    for (final timestamps in [<double>[], List<double>.filled(25, 0)]) {
      await expectLater(
        tools.contactSheet(source, outputPath: '/unused', timestamps: timestamps),
        throwsArgumentError,
      );
    }
    await expectLater(
      tools.contactSheet(source, outputPath: '/unused', columns: 0),
      throwsArgumentError,
    );
    await expectLater(
      tools.contactSheet(source, outputPath: '/unused', cellWidth: 2049),
      throwsArgumentError,
    );
    await expectLater(
      tools.contactSheet(source, outputPath: '/unused', cellHeight: 0),
      throwsArgumentError,
    );
    await expectLater(
      tools.contactSheet(
        source,
        outputPath: '/unused',
        samples: 24,
        cellWidth: 2048,
        cellHeight: 2048,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'actual RGBA budget',
          contains('${defaultFrameBatchBytes ~/ (1024 * 1024)} MiB'),
        ),
      ),
    );
    expect(calls, 0);
  });

  test('invalid source-second selections are refused before any output is created', () async {
    final fixture = await sessionFixture(frames: 2);
    final output = '${fixture.directory.path}/evidence.png';
    for (final time in [-1.0, 0.3, double.nan, double.infinity]) {
      await expectLater(
        fixture.tools.contactSheet(source, outputPath: output, timestamps: [time]),
        throwsArgumentError,
      );
      expect(File(output).existsSync(), isFalse);
    }
  }, skip: Platform.isWindows);

  test('encoder failures preserve diagnostics and do not replace existing evidence', () async {
    final fixture = await sessionFixture(frames: 2, encodeExit: 9);
    final output = File('${fixture.directory.path}/evidence.png');
    await output.writeAsString('previous evidence');
    await expectLater(
      fixture.tools.contactSheet(
        source,
        outputPath: output.path,
        cellWidth: 4,
        cellHeight: 4,
        timestamps: [0, 0.1],
      ),
      throwsA(
        isA<MediaProcessException>()
            .having((error) => error.exitCode, 'exit status', 9)
            .having((error) => error.stderr, 'diagnostic', contains('refused output')),
      ),
    );
    expect(await output.readAsString(), 'previous evidence');
  }, skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1' || Platform.isWindows);
}
