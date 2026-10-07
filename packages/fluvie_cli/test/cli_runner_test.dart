import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:fluvie_cli/src/cli_terminal.dart';
import 'package:test/test.dart';

void main() {
  test(
    'terminal machine failures bound multiline tool diagnostics while preserving their code',
    () {
      final out = StringBuffer();
      CliTerminal(out: out, err: StringBuffer(), machine: true, stage: 'render').finish(
        1,
        failure: CliFailure(
          'Compilation failed.\n${'tool detail\n' * 3000}',
          code: 'capture_failed',
        ),
      );
      expect(out.length, lessThan(6000));
      final event = jsonDecode(out.toString()) as Map<String, Object?>;
      expect(event['code'], 'capture_failed');
      expect(event['message'], 'Compilation failed.');
      expect(event['details'], contains('[truncated]'));
    },
  );

  test('machine failures preserve stable typed codes and verification details', () async {
    final command = RenderCommand(
      resolveFfmpeg: (runner, {binary, allowDownload = true, log = print}) async {
        throw const CliFailure(
          'Output has the wrong canvas.',
          code: 'output_verification_failed',
          details: {
            'receiptPath': '/tmp/video.failed.render.json',
            'verification': {
              'ok': false,
              'mismatches': [
                {'code': 'width_mismatch', 'expected': 64, 'actual': 32},
              ],
            },
          },
        );
      },
    );
    final out = StringBuffer();
    final code = await run(
      ['render', 'cat', '--machine'],
      render: command,
      out: out,
      err: StringBuffer(),
    );
    expect(code, 1);
    final report = jsonDecode(out.toString()) as Map<String, Object?>;
    expect(report['code'], 'output_verification_failed');
    expect(report['details'], containsPair('receiptPath', '/tmp/video.failed.render.json'));
    expect(report['message'], 'Output has the wrong canvas.');
  });

  group('run', () {
    test('machine usage failures end with a stable terminal error event', () async {
      final out = StringBuffer();
      final err = StringBuffer();
      expect(await run(['render', '--machine'], out: out, err: err), exitUsage);
      final event = jsonDecode(out.toString().trim()) as Map<String, Object?>;
      expect(event, containsPair('event', 'error'));
      expect(event, containsPair('code', 'usage_error'));
      expect(event, containsPair('terminal', true));
      expect(event, containsPair('stage', 'render'));
    });

    test('subcommand help explains its options without performing the operation', () async {
      final out = StringBuffer();
      final err = StringBuffer();
      expect(await run(['edit', '--help'], out: out, err: err), 0);
      expect(out.toString(), contains('--no-render'));
      expect(out.toString(), contains('--image-evidence'));
      expect(err.toString(), isEmpty);
    });
    test('--help mentions the init command', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      await run(['--help'], out: out, err: err);

      expect(out.toString(), contains('init'));
    });

    test('the init command dispatches to the injected command', () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final empty = Directory.systemTemp.createTempSync('fluvie_runner_init_');
      addTearDown(() => empty.deleteSync(recursive: true));

      final code = await run(
        ['init'],
        out: out,
        err: err,
        init: InitCommand(workingDirectory: empty),
      );

      expect(code, 0, reason: err.toString());
      expect(out.toString(), contains('Scaffolding a Fluvie project in ${empty.path}'));
      expect(File('${empty.path}/lib/example_video.dart').existsSync(), isTrue);
    });

    test('filesystem failures print the affected path without leaking a stack trace', () async {
      final fixture = Directory.systemTemp.createTempSync('fluvie_runner_failure_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      final blocked = File('${fixture.path}/blocked')..writeAsStringSync('existing file');
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(
        ['init'],
        out: out,
        err: err,
        init: InitCommand(workingDirectory: Directory(blocked.path)),
      );

      expect(code, 1);
      expect(err.toString(), contains(blocked.path));
      expect(err.toString(), contains('Could not access'));
      expect(err.toString(), isNot(contains('#0')));
      expect(blocked.readAsStringSync(), 'existing file');
    });

    test('--help mentions the preview command', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      await run(['--help'], out: out, err: err);

      expect(out.toString(), contains('preview'));
    });

    test('--help prints usage to out and exits 0', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(['--help'], out: out, err: err);

      expect(code, 0);
      expect(out.toString(), contains('fluvie'));
      expect(out.toString(), contains('render'));
      expect(err.toString(), isEmpty);
    });

    test('a bare invocation prints usage to err and exits 64', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(<String>[], out: out, err: err);

      expect(code, exitUsage);
      expect(err.toString(), contains('fluvie'));
      expect(out.toString(), isEmpty);
    });

    test('an unknown option prints the parse error and exits 64', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(['--nope'], out: out, err: err);

      expect(code, exitUsage);
      expect(err.toString(), contains('nope'));
    });

    test('an unknown command prints usage and exits 64', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(['frobnicate'], out: out, err: err);

      expect(code, exitUsage);
      expect(err.toString(), contains('render'));
    });

    test('render without a composition routes to the command and exits 64', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(['render'], out: out, err: err);

      expect(code, exitUsage);
      expect(err.toString(), contains('render needs'));
    });

    test('--help mentions the list command', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      await run(['--help'], out: out, err: err);

      expect(out.toString(), contains('list'));
    });

    test('--help mentions the ffmpeg command', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      await run(['--help'], out: out, err: err);

      expect(out.toString(), contains('ffmpeg'));
    });

    test('the ffmpeg command dispatches and reports the pinned build', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(
        ['ffmpeg', 'status'],
        out: out,
        err: err,
        ffmpeg: FfmpegCommand(cache: FfmpegCache(environment: const {})),
      );

      expect(code, 0);
      expect(out.toString(), contains(pinnedFfmpegBuildLabel));
    });
  });
}
