import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:test/test.dart';

void main() {
  group('run', () {
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
        init: InitCommand(workingDirectory: empty, readLine: () => 'n'),
      );

      expect(code, 0);
      expect(out.toString(), contains('Nothing created'));
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

    test('render without --out routes to the command and exits 64', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(['render', 'demo'], out: out, err: err);

      expect(code, exitUsage);
      expect(err.toString(), contains('--out'));
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
