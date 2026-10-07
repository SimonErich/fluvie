import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:fluvie_cli/src/stage_harness.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void _drop(String _) {}

/// The real gate, but with an empty environment and a nowhere-cache so the
/// resolution stays hermetic (no real `$FLUVIE_FFMPEG`, cache, or network).
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
const ExportFlags _noFlags = (aspect: null, quality: null, format: null, poster: null);

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
    sandbox = Directory.systemTemp.createTempSync('fluvie_pipeline_sandbox_');
    final outDir = Directory.systemTemp.createTempSync('fluvie_pipeline_out_');
    outPath = '${outDir.path}/demo.mp4';
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
    ).thenAnswer((_) async {
      File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(64, 0));
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifestJson()));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    when(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(64, 0));
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifestJson()));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    when(
      () => runner.run('ffmpeg', _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0, 0, 0, 1]);
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
  }

  Future<int> run({
    RenderPipelineOptions options = (
      ffmpegBinary: null,
      projectDir: 'example',
      noCache: false,
      noDownload: false,
      enableImpeller: false,
      verbose: false,
      keepTemp: false,
    ),
    Map<String, String>? environment,
    Map<String, String> extraDefines = const {},
    String harnessPath = 'test/render/capture_harness_test.dart',
    StagedHarness Function(String projectDir)? stage,
    void Function(StringSink out) report = _noop,
    String? cacheKey,
  }) => runRenderPipeline(
    runner: runner,
    createSandbox: () async => sandbox,
    options: options,
    key: 'demo',
    outPath: outPath,
    frames: null,
    flags: _noFlags,
    extraDefines: extraDefines,
    environment: environment,
    harnessPath: harnessPath,
    stage: stage,
    out: out,
    err: err,
    report: report,
    resolveFfmpeg: _hermeticResolve,
    cacheKey: cacheKey,
  );

  test('probe -> capture -> encode -> wrote, exit 0, sandbox cleaned', () async {
    stubHappyPath();

    final code = await run();

    expect(code, 0, reason: err.toString());
    expect(File(outPath).existsSync(), isTrue);
    expect(out.toString(), contains(outPath));
    expect(sandbox.existsSync(), isFalse);
  });

  test('explicit runtime identity invalidates the capture cache without source edits', () async {
    stubHappyPath();
    final args = RenderCommand.buildParser().parse(['demo', '--cache-key', 'remote-revision-2']);
    expect(args.option('cache-key'), 'remote-revision-2');
    final digests = <String>[];
    for (final identity in ['revision-1', 'revision-1', 'revision-2']) {
      await sandbox.create(recursive: true);
      await run(cacheKey: identity);
      final invocations = verify(
        () => runner.run(
          'flutter',
          captureAny(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
        ),
      ).captured.cast<List<String>>();
      digests.add(
        invocations.last.firstWhere(
          (arg) => arg.startsWith('--dart-define=FLUVIE_COMPOSITION_FINGERPRINT='),
        ),
      );
    }
    expect(digests[0], digests[1]);
    expect(digests[2], isNot(digests[1]));
  });

  test('outside-lib target edits invalidate cached renders and retain entry selection', () async {
    stubHappyPath();
    final project = Directory.systemTemp.createTempSync('fluvie_pipeline_target_');
    addTearDown(() => project.deleteSync(recursive: true));
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: consumer\n');
    File(p.join(project.path, '.dart_tool/package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            for (final name in ['consumer', 'fluvie', 'flutter_test'])
              {
                'name': name,
                'rootUri': Directory(
                  name == 'consumer' ? project.path : p.join(project.path, 'packages', name),
                ).uri.toString(),
                'packageUri': 'lib/',
                'languageVersion': '3.12',
              },
          ],
        }),
      );
    final target = File(p.join(project.path, 'videos/cat.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync("String build() => 'cat';\nString alternate() => 'cat';\n");
    final originalModified = target.lastModifiedSync();

    Future<String> render(String entry, {File? source}) async {
      final code = await runRenderPipeline(
        runner: runner,
        createSandbox: () async => sandbox,
        options: (
          ffmpegBinary: null,
          projectDir: project.path,
          noCache: false,
          noDownload: true,
          enableImpeller: false,
          verbose: false,
          keepTemp: true,
        ),
        key: 'cat',
        outPath: outPath,
        frames: null,
        flags: _noFlags,
        extraDefines: const {},
        stage: (projectDir) => stageManagedHarness(
          projectDir: projectDir,
          runner: runner,
          target: resolveFileTarget(
            arg: (source ?? target).path,
            entry: entry,
            project: projectDir,
          ),
          cacheRoot: p.join(project.path, 'adapter-cache'),
        ),
        out: out,
        err: err,
        resolveFfmpeg: _hermeticResolve,
      );
      expect(code, 0, reason: err.toString());
      final receipt =
          jsonDecode(
                File(p.join(p.dirname(outPath), 'demo.render.json')).readAsStringSync(),
              )
              as Map<String, Object?>;
      return receipt['sourceFingerprint']! as String;
    }

    final first = await render('build');
    expect(await render('build'), first, reason: 'unchanged input remains reproducible');
    target
      ..writeAsStringSync("String build() => 'dog';\nString alternate() => 'dog';\n")
      ..setLastModifiedSync(originalModified);
    final changed = await render('build');
    expect(changed, isNot(first), reason: 'same-size source edits must invalidate cached frames');
    expect(
      await render('alternate'),
      isNot(changed),
      reason: 'entry selection remains part of identity',
    );
    expect(
      await render('build'),
      changed,
      reason:
          'staging another entry must not fingerprint cached generated adapters as authored source',
    );
    final external = Directory.systemTemp.createTempSync('fluvie_pipeline_external_');
    addTearDown(() => external.deleteSync(recursive: true));
    final externalTarget = File(p.join(external.path, 'cat.dart'))
      ..writeAsStringSync("import 'helper.dart';\nString build() => title;\n");
    File(p.join(external.path, 'helper.dart')).writeAsStringSync("const title = 'cat';\n");
    await render('build', source: externalTarget);
    final captureArgs =
        verify(
              () => runner.run(
                'flutter',
                captureAny(),
                workingDirectory: any(named: 'workingDirectory'),
              ),
            ).captured.last
            as List<String>;
    expect(
      captureArgs,
      contains('--dart-define=FLUVIE_RENDER_NO_CACHE=true'),
      reason: 'external relative source dependencies are outside the project fingerprint scope',
    );
  });

  test(
    'project-relative authoring inputs select media facts and invalidate changed notes',
    () async {
      final project = Directory.systemTemp.createTempSync('fluvie_pipeline_context_');
      addTearDown(() => project.deleteSync(recursive: true));
      File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: consumer\n');
      final notes = File(p.join(project.path, 'story_assets/story.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync('Miso joined our family in 2020.');
      File(p.join(project.path, 'story_assets/nested/cat.mov'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final specOut = p.join(project.path, 'authored.json');
      final fingerprints = <String>[];
      final contexts = <Map<String, Object?>>[];
      when(
        () => runner.run(
          'flutter',
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((invocation) async {
        final args = invocation.positionalArguments[1] as List<String>;
        String define(String name) => args
            .singleWhere((arg) => arg.startsWith('--dart-define=$name='))
            .substring('--dart-define=$name='.length);
        fingerprints.add(define('FLUVIE_COMPOSITION_FINGERPRINT'));
        final context = File(define('FLUVIE_AI_CONTEXT_FILE')).readAsStringSync();
        contexts.add(
          jsonDecode(context.substring(context.indexOf('\n') + 1)) as Map<String, Object?>,
        );
        File(specOut).writeAsStringSync('{}');
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      var pairResolutions = 0;
      Future<int> author() => runRenderPipeline(
        runner: runner,
        createSandbox: () async => sandbox,
        options: (
          ffmpegBinary: null,
          projectDir: project.path,
          noCache: false,
          noDownload: true,
          enableImpeller: false,
          verbose: false,
          keepTemp: true,
        ),
        key: '',
        outPath: outPath,
        frames: null,
        flags: _noFlags,
        extraDefines: {
          'FLUVIE_AI_PROMPT': 'Tell our cat story',
          'FLUVIE_RENDER_SPEC_OUT': specOut,
          'FLUVIE_OPERATION': 'author',
        },
        authorAssetsDir: 'story_assets',
        contextFiles: ['story_assets/story.txt'],
        stage: (projectDir) => StagedHarness(
          projectDir: projectDir,
          dir: project,
          harnessPath: 'external_adapter.dart',
          ephemeral: false,
        ),
        resolveToolchain:
            (
              runner, {
              binary,
              probeBinary,
              mode = 'managed',
              allowDownload = true,
              log = _drop,
            }) async {
              pairResolutions++;
              return FfmpegToolchain(
                ffmpegPath: p.join(project.path, 'unavailable-ffmpeg'),
                ffprobePath: p.join(project.path, 'unavailable-ffprobe'),
                build: 'fixture',
                ffmpegVersion: 'fixture',
                ffprobeVersion: 'fixture',
              );
            },
        out: out,
        err: err,
      );

      expect(await author(), 0);
      expect(pairResolutions, 1, reason: 'media probing must use the project-relative asset root');
      expect(contexts.single['totalAssets'], 2);
      expect((contexts.single['notes']! as List).single, containsPair('path', notes.path));
      notes.writeAsStringSync('Miso joined our family in 2021.');
      expect(await author(), 0);
      expect(
        fingerprints.last,
        isNot(fingerprints.first),
        reason: 'selected context bytes are render inputs',
      );
    },
  );

  test('an encoded custom renderer receipt moves the artifact without encoding twice', () async {
    stubHappyPath();
    when(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      final encoded = File('${sandbox.path}/encoded.mp4')..writeAsBytesSync([9, 8, 7]);
      File('${sandbox.path}/render-result.json').writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'kind': 'encoded',
          'filePath': encoded.path,
          'outputIntent': {'width': 100, 'height': 80, 'codec': 'h264'},
        }),
      );
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    expect(await run(), 0);
    expect(File(outPath).readAsBytesSync(), [9, 8, 7]);
    final receiptPath = '${p.withoutExtension(outPath)}.render.json';
    final receipt = jsonDecode(File(receiptPath).readAsStringSync()) as Map<String, Object?>;
    expect(
      receipt['capture'],
      containsPair('outputIntent', {'width': 100, 'height': 80, 'codec': 'h264'}),
    );
    verifyNever(
      () => runner.run('ffmpeg', _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    );
  });

  test('a renderer receipt cannot move an artifact outside its workspace', () async {
    stubHappyPath();
    final outside = File(outPath)..writeAsBytesSync([1]);
    when(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      File('${sandbox.path}/render-result.json').writeAsStringSync(
        jsonEncode({'schemaVersion': 1, 'kind': 'encoded', 'filePath': outside.path}),
      );
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    await expectLater(
      run(),
      throwsA(
        predicate((error) => error.toString().contains('inside its output workspace')),
      ),
    );
    expect(outside.readAsBytesSync(), [1]);
    verifyNever(
      () => runner.run('ffmpeg', _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    );
  });

  test('forwards a per-run environment to the capture (flutter test)', () async {
    stubHappyPath();

    await run(environment: const {'FLUVIE_PROGRESS_FILE': '/tmp/p', 'ANTHROPIC_API_KEY': 'sk'});

    final captured = verify(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: captureAny(named: 'environment'),
      ),
    ).captured.single;
    expect(captured, {'FLUVIE_PROGRESS_FILE': '/tmp/p', 'ANTHROPIC_API_KEY': 'sk'});
  });

  test(
    'a resolved ffmpeg off PATH is prepended to the capture PATH, keeping the run env',
    () async {
      // The capture extracts a clip's frames itself, in the test subprocess, so it
      // needs the gate-resolved ffmpeg on PATH too, not just the encode the CLI
      // spawns directly. Without this a cache-only ffmpeg encodes fine while every
      // Clip fails to decode.
      stubHappyPath();
      const binary = '/opt/ffmpeg/bin/ffmpeg';
      when(
        () => runner.run(binary, const ['-version']),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
      when(
        () => runner.run(binary, _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0, 0, 0, 1]);
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });

      final code = await run(
        options: (
          ffmpegBinary: binary,
          projectDir: 'example',
          noCache: false,
          noDownload: false,
          enableImpeller: false,
          verbose: false,
          keepTemp: false,
        ),
        environment: const {'FLUVIE_PROGRESS_FILE': '/tmp/p'},
      );

      expect(code, 0, reason: err.toString());
      final captured =
          verify(
                () => runner.run(
                  'flutter',
                  any(),
                  workingDirectory: any(named: 'workingDirectory'),
                  environment: captureAny(named: 'environment'),
                ),
              ).captured.single
              as Map<String, String>;
      expect(
        captured['FLUVIE_PROGRESS_FILE'],
        '/tmp/p',
        reason: 'prepending PATH must not drop the per-run environment',
      );
      expect(captured['PATH'], startsWith('/opt/ffmpeg/bin'));
    },
  );

  test('a bare ffmpeg already on PATH needs no PATH entry', () async {
    stubHappyPath();

    await run(environment: const {'FLUVIE_PROGRESS_FILE': '/tmp/p'});

    final captured =
        verify(
              () => runner.run(
                'flutter',
                any(),
                workingDirectory: any(named: 'workingDirectory'),
                environment: captureAny(named: 'environment'),
              ),
            ).captured.single
            as Map<String, String>;
    expect(captured, isNot(contains('PATH')));
  });

  test('keepTemp preserves the sandbox and reports where it is', () async {
    stubHappyPath();

    final code = await run(
      options: (
        ffmpegBinary: null,
        projectDir: 'example',
        noCache: false,
        noDownload: false,
        enableImpeller: false,
        verbose: false,
        keepTemp: true,
      ),
    );

    expect(code, 0);
    expect(sandbox.existsSync(), isTrue);
    expect(err.toString(), contains(sandbox.path));
  });

  test('a custom harnessPath flows through to the spawned flutter test', () async {
    stubHappyPath();

    final code = await run(harnessPath: '.fluvie_playground/abc/harness_test.dart');

    expect(code, 0, reason: err.toString());
    final captured =
        verify(
              () => runner.run(
                'flutter',
                captureAny(),
                workingDirectory: any(named: 'workingDirectory'),
                environment: any(named: 'environment'),
              ),
            ).captured.single
            as List<String>;
    expect(captured, contains('.fluvie_playground/abc/harness_test.dart'));
    expect(captured, isNot(contains('test/render/capture_harness_test.dart')));
  });

  test('enableImpeller passes --enable-impeller through to the capture', () async {
    stubHappyPath();

    final code = await run(
      options: (
        ffmpegBinary: null,
        projectDir: 'example',
        noCache: false,
        noDownload: false,
        enableImpeller: true,
        verbose: false,
        keepTemp: false,
      ),
    );

    expect(code, 0, reason: err.toString());
    final captured =
        verify(
              () => runner.run(
                'flutter',
                captureAny(),
                workingDirectory: any(named: 'workingDirectory'),
                environment: any(named: 'environment'),
              ),
            ).captured.single
            as List<String>;
    expect(captured, contains('--enable-impeller'));
  });

  test('the report callback runs after a successful encode', () async {
    stubHappyPath();
    var reported = false;

    await run(report: (sink) => reported = true);

    expect(reported, isTrue);
  });

  group('stage', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('fluvie_pipeline_project_');
      addTearDown(() {
        if (project.existsSync()) project.deleteSync(recursive: true);
      });
    });

    StagedHarness stageIn(String projectDir) => stageHarness(
      projectDir: projectDir,
      harnessSource: '// GENERATED\nvoid main() {}\n',
      relativeDir: '.fluvie_playground/abc',
    );

    test('a staged harness replaces the harnessPath in the capture argv', () async {
      stubHappyPath();

      final code = await run(options: _optionsFor(project.path), stage: stageIn);

      expect(code, 0, reason: err.toString());
      final captured =
          verify(
                () => runner.run(
                  'flutter',
                  captureAny(),
                  workingDirectory: any(named: 'workingDirectory'),
                ),
              ).captured.single
              as List<String>;
      expect(captured, contains('.fluvie_playground/abc/harness_test.dart'));
      expect(captured, isNot(contains('test/render/capture_harness_test.dart')));
    });

    test('the stage callback is handed the resolved project directory', () async {
      stubHappyPath();
      String? seen;

      await run(
        options: _optionsFor(project.path),
        stage: (projectDir) {
          seen = projectDir;
          return stageIn(projectDir);
        },
      );

      expect(seen, project.path);
    });

    test('an ephemeral staging is cleaned up after the render', () async {
      stubHappyPath();

      await run(options: _optionsFor(project.path), stage: stageIn);

      expect(Directory('${project.path}/.fluvie_playground/abc').existsSync(), isFalse);
    });

    test('the staging is cleaned up even when the capture fails', () async {
      stubHappyPath();
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: 'boom', stderr: ''));

      await expectLater(
        run(options: _optionsFor(project.path), stage: stageIn),
        throwsA(isA<Object>()),
      );

      expect(Directory('${project.path}/.fluvie_playground/abc').existsSync(), isFalse);
    });

    test('the harness is staged before the sandbox, and the render still runs in it', () async {
      stubHappyPath();

      await run(options: _optionsFor(project.path), stage: stageIn);

      verify(() => runner.run('flutter', any(), workingDirectory: project.path)).called(1);
    });
  });

  test('an ffmpeg below the floor aborts before any capture', () async {
    when(
      () => runner.run('ffmpeg', const ['-version']),
    ).thenAnswer(
      (_) async => const ProcessRunResult(
        exitCode: 0,
        stdout: 'ffmpeg version 5.1.4 Copyright (c) 2000-2023 the FFmpeg developers',
        stderr: '',
      ),
    );

    await expectLater(run(), throwsA(isA<Object>()));
    verifyNever(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    );
  });
}

void _noop(StringSink out) {}

/// The default pipeline options, pointed at [projectDir].
RenderPipelineOptions _optionsFor(String projectDir) => (
  ffmpegBinary: null,
  projectDir: projectDir,
  noCache: false,
  noDownload: false,
  enableImpeller: false,
  verbose: false,
  keepTemp: false,
);
