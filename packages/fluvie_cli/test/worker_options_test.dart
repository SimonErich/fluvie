import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:test/test.dart';

const _target = FileTarget(
  projectDir: '/missing/project',
  path: '/missing/project/video.dart',
  entry: 'build',
);
const _toolchain = FfmpegToolchain(
  ffmpegPath: 'ffmpeg',
  ffprobePath: 'ffprobe',
  build: 'test',
  ffmpegVersion: 'test',
  ffprobeVersion: 'test',
);

void main() {
  for (final value in ['0', '-1', 'later']) {
    test(
      'session rejects an invalid HTTP deadline before opening its descriptor ($value)',
      () async {
        final args = SessionCommand.buildParser().parse([
          'missing.json',
          'frame',
          '--timeout',
          value,
        ]);
        await expectLater(
          const SessionCommand().execute(args, out: StringBuffer(), err: StringBuffer()),
          throwsA(
            isA<CliFailure>().having((failure) => failure.message, 'message', contains('timeout')),
          ),
        );
      },
    );
  }
  for (final duration in [Duration.zero, const Duration(seconds: -1)]) {
    test('invalid launch deadlines fail before staging ($duration)', () async {
      await expectLater(
        NativeRenderWorker.start(
          target: _target,
          toolchain: _toolchain,
          err: StringBuffer(),
          startupTimeout: duration,
        ),
        throwsArgumentError,
      );
      await expectLater(
        NativeRenderWorker.start(
          target: _target,
          toolchain: _toolchain,
          err: StringBuffer(),
          requestTimeout: duration,
        ),
        throwsArgumentError,
      );
    });
  }
  for (final option in ['startup-timeout', 'request-timeout']) {
    for (final value in ['0', '-1', 'later']) {
      test('workspace rejects --$option $value before resolving the source', () async {
        final args = WorkspaceCommand.buildParser().parse(['missing.dart', '--$option', value]);
        await expectLater(
          const WorkspaceCommand().execute(args, out: StringBuffer(), err: StringBuffer()),
          throwsA(
            isA<CliFailure>().having((failure) => failure.message, 'message', contains(option)),
          ),
        );
      });
    }
  }
}
