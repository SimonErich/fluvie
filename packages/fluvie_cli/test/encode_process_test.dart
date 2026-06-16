import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/encode_process.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

const _args = ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4'];

Map<String, Object?> _manifestJson({List<Object?>? args}) => {
  'schemaVersion': 1,
  'width': 320,
  'height': 240,
  'fps': 30,
  'frameCount': 48,
  'framesFileName': 'frames.rgba',
  'outputFileName': 'out.mp4',
  'renderDigest': 'cbf29ce484222325',
  'ffmpegArgs': args ?? _args,
};

void main() {
  late _MockProcessRunner runner;
  late Directory sandbox;
  late String outPath;

  setUp(() {
    runner = _MockProcessRunner();
    sandbox = Directory.systemTemp.createTempSync('fluvie_cli_encode_');
    final outDir = Directory.systemTemp.createTempSync('fluvie_cli_encode_out_');
    outPath = '${outDir.path}/nested/final.mp4';
    addTearDown(() {
      sandbox.deleteSync(recursive: true);
      outDir.deleteSync(recursive: true);
    });
  });

  void writeManifest({List<Object?>? args}) {
    File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifestJson(args: args)));
  }

  void stubFfmpeg({int exitCode = 0, String stderr = '', bool producesOutput = true}) {
    when(
      () => runner.run('ffmpeg', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      if (producesOutput && exitCode == 0) {
        File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0, 0, 0, 1]);
      }
      return ProcessRunResult(exitCode: exitCode, stdout: '', stderr: stderr);
    });
  }

  group('runEncode', () {
    test('spawns ffmpeg with exactly the manifest args, cwd = sandbox', () async {
      writeManifest();
      stubFfmpeg();

      await runEncode(runner: runner, sandbox: sandbox, outPath: outPath);

      verify(() => runner.run('ffmpeg', _args, workingDirectory: sandbox.path)).called(1);
    });

    test('moves out.mp4 to --out, creating parent directories', () async {
      writeManifest();
      stubFfmpeg();

      final output = await runEncode(runner: runner, sandbox: sandbox, outPath: outPath);

      expect(output.path, outPath);
      expect(File(outPath).readAsBytesSync(), [0, 0, 0, 1]);
      expect(
        File('${sandbox.path}/out.mp4').existsSync(),
        isFalse,
        reason: 'the sandbox copy is removed after the move',
      );
    });

    test('an explicit ffmpeg binary is used', () async {
      writeManifest();
      when(
        () => runner.run('/opt/ffmpeg', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        File('${sandbox.path}/out.mp4').writeAsBytesSync(const [1]);
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });

      await runEncode(
        runner: runner,
        sandbox: sandbox,
        outPath: outPath,
        ffmpegBinary: '/opt/ffmpeg',
      );

      verify(() => runner.run('/opt/ffmpeg', _args, workingDirectory: sandbox.path)).called(1);
    });

    test('a missing manifest is a capture failure and ffmpeg never runs', () async {
      await expectLater(
        () => runEncode(runner: runner, sandbox: sandbox, outPath: outPath),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('capture'))),
      );
      verifyNever(
        () => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')),
      );
    });

    test('an escaping manifest arg is rejected before ffmpeg runs', () async {
      writeManifest(args: ['-i', 'frames.rgba', '../../evil.mp4']);

      await expectLater(
        () => runEncode(runner: runner, sandbox: sandbox, outPath: outPath),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('escape'))),
      );
      verifyNever(
        () => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')),
      );
    });

    test('a non-zero ffmpeg exit throws with the stderr tail', () async {
      writeManifest();
      stubFfmpeg(exitCode: 187, stderr: 'Invalid buffer size', producesOutput: false);

      await expectLater(
        () => runEncode(runner: runner, sandbox: sandbox, outPath: outPath),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('187'))
              .having((e) => e.message, 'message', contains('Invalid buffer size')),
        ),
      );
    });

    test('a zero exit without an output file is reported', () async {
      writeManifest();
      stubFfmpeg(producesOutput: false);

      await expectLater(
        () => runEncode(runner: runner, sandbox: sandbox, outPath: outPath),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('produced no'))),
      );
    });
  });

  group('runEncode image sequence', () {
    const seqArgs = ['-f', 'rawvideo', '-i', 'frames.rgba', 'frame_%06d.png'];
    late Directory outDir;
    late String outSeqPath;

    setUp(() {
      outDir = Directory.systemTemp.createTempSync('fluvie_cli_encode_seq_');
      outSeqPath = '${outDir.path}/frames';
      addTearDown(() => outDir.deleteSync(recursive: true));
    });

    void writeSeqManifest() {
      final json = _manifestJson(args: seqArgs)..['outputFileName'] = 'frame_%06d.png';
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(json));
    }

    void stubSeqFfmpeg({int stills = 3, bool produces = true}) {
      when(
        () => runner.run('ffmpeg', seqArgs, workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        if (produces) {
          for (var i = 0; i < stills; i++) {
            final name = 'frame_${i.toString().padLeft(6, '0')}.png';
            File('${sandbox.path}/$name').writeAsBytesSync([i, i]);
          }
        }
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
    }

    test('collects every produced still into the --out directory', () async {
      writeSeqManifest();
      stubSeqFfmpeg(stills: 4);

      final output = await runEncode(runner: runner, sandbox: sandbox, outPath: outSeqPath);

      expect(output.path, outSeqPath, reason: 'returns the destination directory');
      final landed = Directory(
        outSeqPath,
      ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList()..sort();
      expect(landed, [
        'frame_000000.png',
        'frame_000001.png',
        'frame_000002.png',
        'frame_000003.png',
      ]);
      expect(File('$outSeqPath/frame_000002.png').readAsBytesSync(), [2, 2]);
      expect(
        sandbox.listSync().whereType<File>().where((f) => f.path.endsWith('.png')),
        isEmpty,
        reason: 'the sandbox stills are removed after the move',
      );
    });

    test('creates the destination directory when it does not exist', () async {
      writeSeqManifest();
      stubSeqFfmpeg(stills: 2);
      final nested = '${outDir.path}/deep/stills';

      await runEncode(runner: runner, sandbox: sandbox, outPath: nested);

      expect(Directory(nested).existsSync(), isTrue);
      expect(Directory(nested).listSync().whereType<File>(), hasLength(2));
    });

    test('a zero exit that produced no stills names the pattern', () async {
      writeSeqManifest();
      stubSeqFfmpeg(produces: false);

      await expectLater(
        () => runEncode(runner: runner, sandbox: sandbox, outPath: outSeqPath),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('frame_%06d.png'))
              .having((e) => e.message, 'message', contains('produced no')),
        ),
      );
    });
  });

  group('runEncode poster invocation', () {
    const posterArgs = ['-i', 'frames.rgba', 'poster.png'];

    void writePosterManifest() {
      final json = _manifestJson()
        ..['posterFileName'] = 'poster.png'
        ..['posterArgs'] = posterArgs;
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(json));
    }

    void stubBoth() {
      when(
        () => runner.run('ffmpeg', _args, workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0, 0, 0, 1]);
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      when(
        () => runner.run('ffmpeg', posterArgs, workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        File('${sandbox.path}/poster.png').writeAsBytesSync(const [9, 9]);
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
    }

    test('runs the second poster invocation and writes a sibling poster png', () async {
      writePosterManifest();
      stubBoth();

      await runEncode(runner: runner, sandbox: sandbox, outPath: outPath);

      verify(() => runner.run('ffmpeg', _args, workingDirectory: sandbox.path)).called(1);
      verify(() => runner.run('ffmpeg', posterArgs, workingDirectory: sandbox.path)).called(1);
      final posterPath = outPath.replaceFirst(RegExp(r'\.[^.]+$'), '.poster.png');
      expect(File(posterPath).existsSync(), isTrue);
      expect(File(posterPath).readAsBytesSync(), [9, 9]);
    });

    test('a poster ffmpeg failure surfaces as a CliFailure', () async {
      writePosterManifest();
      when(
        () => runner.run('ffmpeg', _args, workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        File('${sandbox.path}/out.mp4').writeAsBytesSync(const [1]);
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      when(
        () => runner.run('ffmpeg', posterArgs, workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: '', stderr: 'boom'));

      await expectLater(
        () => runEncode(runner: runner, sandbox: sandbox, outPath: outPath),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('poster'))),
      );
    });

    test('poster ffmpeg exiting 0 with no file surfaces as a CliFailure', () async {
      writePosterManifest();
      when(
        () => runner.run('ffmpeg', _args, workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        File('${sandbox.path}/out.mp4').writeAsBytesSync(const [1]);
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      when(
        () => runner.run('ffmpeg', posterArgs, workingDirectory: any(named: 'workingDirectory')),
        // Succeeds but writes no poster.png, so the existence guard must fire.
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: '', stderr: ''));

      await expectLater(
        () => runEncode(runner: runner, sandbox: sandbox, outPath: outPath),
        throwsA(
          isA<CliFailure>().having((e) => e.message, 'message', contains('no poster')),
        ),
      );
    });
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });
}
