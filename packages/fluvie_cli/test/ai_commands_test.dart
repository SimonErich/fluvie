import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/src/edit_command.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/generate_command.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void _drop(String _) {}

/// The real gate with an empty environment and a nowhere-cache, keeping
/// resolution hermetic while still probing through [runner].
Future<String> _hermeticResolve(
  ProcessRunner runner, {
  String? binary,
  bool allowDownload = true,
  ProvisionLog log = _drop,
}) => ensureFfmpeg(
  runner,
  binary: binary,
  allowDownload: allowDownload,
  log: log,
  environment: const {},
  cache: FfmpegCache(abi: Abi.linuxX64, environment: const {}),
);

const _banner8 = 'ffmpeg version 8.0.1 Copyright (c) 2000-2025 the FFmpeg developers';
const _encodeArgs = ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4'];

Map<String, Object?> _manifestJson() => {
  'schemaVersion': 1,
  'width': 320,
  'height': 240,
  'fps': 30,
  'frameCount': 48,
  'framesFileName': 'frames.rgba',
  'outputFileName': 'out.mp4',
  'renderDigest': 'cbf29ce484222325',
  'ffmpegArgs': _encodeArgs,
};

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  late _MockProcessRunner runner;
  late Directory sandbox;
  late String outPath;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    runner = _MockProcessRunner();
    sandbox = Directory.systemTemp.createTempSync('fluvie_cli_ai_sandbox_');
    final outDir = Directory.systemTemp.createTempSync('fluvie_cli_ai_out_');
    outPath = '${outDir.path}/demo.mp4';
    final configFile = File('../../.dart_tool/package_config.json');
    final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    for (final package in (config['packages'] as List).cast<Map<String, dynamic>>()) {
      package['rootUri'] = configFile.absolute.uri.resolve(package['rootUri'] as String).toString();
    }
    File('${sandbox.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(config));
    File(
      '${sandbox.path}/pubspec.yaml',
    ).writeAsStringSync('name: authored_video\ndependencies:\n  fluvie: any\n');
    out = StringBuffer();
    err = StringBuffer();
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
      outDir.deleteSync(recursive: true);
    });
  });

  void stubHappyPath() {
    when(
      () => runner.run('ffmpeg', const ['-version']),
    ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
    when(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((invocation) async {
      final argv = invocation.positionalArguments[1] as List<String>;
      if (argv.contains('--dart-define=FLUVIE_OPERATION=author')) {
        final document = argv
            .singleWhere((arg) => arg.startsWith('--dart-define=FLUVIE_RENDER_SPEC_OUT='))
            .substring('--dart-define=FLUVIE_RENDER_SPEC_OUT='.length);
        File(document).writeAsStringSync(
          jsonEncode({
            'fluvieSpec': 1,
            'scenes': [
              {
                'duration': '1s',
                'children': [
                  {'type': 'Text', 'text': 'Cat'},
                ],
              },
            ],
          }),
        );
      } else {
        final output = argv
            .singleWhere((arg) => arg.startsWith('--dart-define=FLUVIE_RENDER_OUT_DIR='))
            .substring('--dart-define=FLUVIE_RENDER_OUT_DIR='.length);
        File('$output/frames.rgba').writeAsBytesSync(List.filled(64, 0));
        File('$output/manifest.json').writeAsStringSync(jsonEncode(_manifestJson()));
      }
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    when(
      () => runner.run('ffmpeg', _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((invocation) async {
      File(
        '${invocation.namedArguments[#workingDirectory]}/out.mp4',
      ).writeAsBytesSync(const [0, 0, 0, 1]);
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
  }

  List<String> capturedFlutterArgv() =>
      verify(
            () => runner.run(
              'flutter',
              captureAny(),
              workingDirectory: any(named: 'workingDirectory'),
              environment: any(named: 'environment'),
            ),
          ).captured.first
          as List<String>;

  Future<Directory> sandboxFactory() => sandbox.createTemp('capture_');

  group('generate', () {
    Future<int> run(List<String> args) =>
        GenerateCommand(
          runner: runner,
          createSandbox: sandboxFactory,
          resolveFfmpeg: _hermeticResolve,
          environment: const {'ANTHROPIC_API_KEY': 'test', 'GEMINI_API_KEY': 'test'},
        ).execute(
          GenerateCommand.buildParser().parse([
            for (final arg in args)
              if (arg == 'example') sandbox.path else arg,
          ]),
          out: out,
          err: err,
        );

    test('default Flutter code and spec exist before capture and survive its failure', () async {
      final project = Directory('${File(outPath).parent.path}/project')..createSync();
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: authored_video\n');
      File('${project.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          File('${sandbox.path}/.dart_tool/package_config.json').readAsStringSync(),
        );
      final dartOut = File('${project.path}/lib/generated_video.dart');
      final specOut = '${File(outPath).parent.path}/demo.fluvie.json';
      when(() => runner.run('ffmpeg', const ['-version'])).thenAnswer(
        (_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''),
      );
      when(
        () => runner.run(
          'flutter',
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((invocation) async {
        final argv = invocation.positionalArguments[1] as List<String>;
        if (argv.contains('--dart-define=FLUVIE_OPERATION=author')) {
          final output = argv
              .singleWhere((a) => a.startsWith('--dart-define=FLUVIE_RENDER_SPEC_OUT='))
              .substring('--dart-define=FLUVIE_RENDER_SPEC_OUT='.length);
          File(output)
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(
              jsonEncode({
                'fluvieSpec': 1,
                'scenes': [
                  {
                    'duration': '1s',
                    'children': [
                      {'type': 'Text', 'text': 'Miso'},
                    ],
                  },
                ],
              }),
            );
          return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
        }
        expect(
          dartOut.existsSync(),
          isTrue,
          reason: 'authoring must publish readable code before capture',
        );
        expect(File(specOut).existsSync(), isTrue);
        return const ProcessRunResult(exitCode: 1, stdout: 'capture failed', stderr: '');
      });
      expect(
        await run([
          'Miso story',
          '--project',
          project.path,
          '--out',
          outPath,
          '--provider',
          'ollama',
        ]),
        1,
      );
      expect(dartOut.readAsStringSync(), contains('Miso'));
      expect(out.toString(), contains('Dart ${dartOut.path}'));
    });

    test('authors and renders: prompt + spec-out defines, spec reported', () async {
      stubHappyPath();
      final code = await run(['a coffee promo', '--out', outPath, '--project', 'example']);

      expect(code, 0, reason: err.toString());
      final argv = capturedFlutterArgv();
      expect(argv, contains('--dart-define=FLUVIE_AI_PROMPT=a coffee promo'));
      expect(File('${File(outPath).parent.path}/demo.fluvie.json').existsSync(), isTrue);
      expect(argv.any((a) => a.contains('FLUVIE_AI_PROVIDER')), isFalse);
      expect(out.toString(), contains(outPath));
      expect(out.toString(), contains('demo.fluvie.json'));
    });

    test('forwards --provider and --spec-out', () async {
      stubHappyPath();
      final specOut = '${sandbox.path}/custom.fluvie.json';
      await run([
        'promo',
        '--out',
        outPath,
        '--project',
        'example',
        '--provider',
        'gemini',
        '--spec-out',
        specOut,
      ]);

      final argv = capturedFlutterArgv();
      expect(argv, contains('--dart-define=FLUVIE_AI_PROVIDER=gemini'));
      expect(File(specOut).existsSync(), isTrue);
    });

    test('a missing prompt is a usage error (64)', () async {
      expect(await run(['--out', outPath]), 64);
      expect(err.toString(), contains('prompt'));
    });

    test('missing provider configuration fails before spawning or provisioning', () async {
      final code = await GenerateCommand(runner: runner, environment: const {}).execute(
        GenerateCommand.buildParser().parse(['cat life', '--project', sandbox.path]),
        out: out,
        err: err,
      );
      expect(code, 1);
      expect(err.toString(), contains('ANTHROPIC_API_KEY'));
      verifyNever(() => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')));
    });

    test('a bad --frames is a usage error (64)', () async {
      expect(await run(['promo', '--out', outPath, '--frames', 'lots']), 64);
      expect(err.toString(), contains('--frames'));
    });

    test('image evidence requires an explicitly selected catalog', () async {
      expect(await run(['cat story', '--image-evidence', '--project', sandbox.path]), 64);
      expect(err.toString(), contains('--catalog'));
    });

    test('a capture failure is an operational failure (1)', () async {
      when(
        () => runner.run('ffmpeg', const ['-version']),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
      when(
        () => runner.run(
          'flutter',
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: 'boom', stderr: ''));

      expect(await run(['promo', '--out', outPath, '--project', 'example']), 1);
    });

    test('authors readable Dart without FFmpeg provisioning or encoding', () async {
      final specOut = '${File(outPath).parent.path}/authored.fluvie.json';
      final dartOut = '${File(outPath).parent.path}/cat.dart';
      final notes = File('${File(outPath).parent.path}/story.txt')
        ..writeAsStringSync('My cat was born in Vienna.');
      when(
        () => runner.run(
          'flutter',
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((invocation) async {
        final argv = invocation.positionalArguments[1] as List<String>;
        final contextPath = argv
            .singleWhere((arg) => arg.startsWith('--dart-define=FLUVIE_AI_CONTEXT_FILE='))
            .split('=')
            .skip(2)
            .join('=');
        expect(File(contextPath).readAsStringSync(), contains('My cat was born in Vienna.'));
        final pendingSpec = argv
            .singleWhere((arg) => arg.startsWith('--dart-define=FLUVIE_RENDER_SPEC_OUT='))
            .substring('--dart-define=FLUVIE_RENDER_SPEC_OUT='.length);
        File(pendingSpec).writeAsStringSync(
          jsonEncode({
            'fluvieSpec': 1,
            'fps': 30,
            'width': 64,
            'height': 64,
            'scenes': [
              {
                'duration': '1s',
                'children': [
                  {'type': 'Text', 'text': 'Cat'},
                ],
              },
            ],
          }),
        );
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      expect(
        await run([
          'cat life',
          '--project',
          sandbox.path,
          '--no-render',
          '--context-file',
          notes.path,
          '--spec-out',
          specOut,
          '--dart-out',
          dartOut,
        ]),
        0,
        reason: err.toString(),
      );
      expect(capturedFlutterArgv(), contains('--dart-define=FLUVIE_OPERATION=author'));
      expect(File(dartOut).readAsStringSync(), contains('Video build()'));
      expect(File(dartOut).readAsStringSync(), contains('Cat'));
      verifyNever(
        () => runner.run('ffmpeg', any(), workingDirectory: any(named: 'workingDirectory')),
      );
    });

    test('deriveSpecOut swaps the extension, or appends when none', () {
      expect(GenerateCommand.deriveSpecOut('/tmp/clip.mp4'), '/tmp/clip.fluvie.json');
      expect(GenerateCommand.deriveSpecOut('/tmp/video'), '/tmp/video.fluvie.json');
    });
  });

  group('edit', () {
    late String specPath;
    setUp(() {
      specPath = '${sandbox.path}/in.fluvie.json';
      File(specPath).writeAsStringSync('{"fluvieSpec":1}');
    });

    Future<int> run(List<String> args) =>
        EditCommand(
          runner: runner,
          createSandbox: sandboxFactory,
          resolveFfmpeg: _hermeticResolve,
          environment: const {'ANTHROPIC_API_KEY': 'test', 'GEMINI_API_KEY': 'test'},
        ).execute(
          EditCommand.buildParser().parse([
            for (final arg in args)
              if (arg == 'example') sandbox.path else arg,
          ]),
          out: out,
          err: err,
        );

    test('loads the base spec and renders: base + change + spec-out defines', () async {
      stubHappyPath();
      final code = await run([
        specPath,
        'make',
        'it',
        'blue',
        '--out',
        outPath,
        '--project',
        'example',
      ]);

      expect(code, 0, reason: err.toString());
      final argv = capturedFlutterArgv();
      expect(argv, contains('--dart-define=FLUVIE_AI_BASE_SPEC=$specPath'));
      expect(argv, contains('--dart-define=FLUVIE_AI_PROMPT=make it blue'));
      // spec-out defaults to overwriting the input spec.
      expect(File(specPath).readAsStringSync(), contains('scenes'));
    });

    test('a missing spec file is a usage error (64)', () async {
      expect(await run(['/no/such.json', 'change', '--out', outPath]), 64);
      expect(err.toString(), contains('not found'));
    });

    test('too few arguments is a usage error (64)', () async {
      expect(await run([specPath]), 64);
      expect(err.toString(), contains('change'));
    });

    test('an empty change is a usage error (64)', () async {
      expect(await run([specPath, '', '--out', outPath]), 64);
      expect(err.toString(), contains('change'));
    });

    test('out defaults inside the source build directory', () async {
      stubHappyPath();
      expect(
        await run([specPath, 'make it blue', '--project', sandbox.path]),
        0,
        reason: err.toString(),
      );
      expect(out.toString(), contains('${sandbox.path}/build/fluvie/in.mp4'));
    });

    test('relative spec output resolves inside the selected source project', () async {
      stubHappyPath();
      final relative = 'build/fluvie/edited_${sandbox.path.split('/').last}.fluvie.json';
      final incorrect = File(relative);
      addTearDown(() {
        if (incorrect.existsSync()) incorrect.deleteSync();
      });
      expect(
        await run([
          specPath,
          'make it blue',
          '--project',
          sandbox.path,
          '--spec-out',
          relative,
          '--no-render',
        ]),
        0,
      );
      expect(File('${sandbox.path}/$relative').existsSync(), isTrue);
      expect(incorrect.existsSync(), isFalse);
    });

    test('a bad --frames is a usage error (64)', () async {
      expect(await run([specPath, 'change', '--out', outPath, '--frames', 'x']), 64);
      expect(err.toString(), contains('--frames'));
    });

    test('forwards --provider and surfaces a capture failure (1)', () async {
      when(
        () => runner.run('ffmpeg', const ['-version']),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
      when(
        () => runner.run(
          'flutter',
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: 'boom', stderr: ''));

      final code = await run([
        specPath,
        'make it blue',
        '--out',
        outPath,
        '--project',
        'example',
        '--provider',
        'ollama',
      ]);
      expect(code, 1);
    });
  });

  group('render --spec', () {
    Future<int> run(List<String> args) => RenderCommand(
      runner: runner,
      createSandbox: sandboxFactory,
      resolveFfmpeg: _hermeticResolve,
    ).execute(RenderCommand.buildParser().parse(args), out: out, err: err);

    test('passes FLUVIE_RENDER_SPEC and an empty key', () async {
      stubHappyPath();
      final specPath = '${sandbox.path}/in.fluvie.json';
      File(specPath).writeAsStringSync('{"fluvieSpec":1}');

      final code = await run(['--spec', specPath, '--out', outPath, '--project', 'example']);

      expect(code, 0, reason: err.toString());
      final argv = capturedFlutterArgv();
      expect(argv, contains('--dart-define=FLUVIE_RENDER_SPEC=$specPath'));
      expect(argv, contains('--dart-define=FLUVIE_RENDER_KEY='));
    });

    test('a key together with --spec is a usage error (64)', () async {
      final specPath = '${sandbox.path}/in.fluvie.json';
      File(specPath).writeAsStringSync('{"fluvieSpec":1}');
      expect(await run(['demo', '--spec', specPath, '--out', outPath]), 64);
      expect(err.toString(), contains('--spec'));
    });
  });
}
