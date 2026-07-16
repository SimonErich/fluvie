import 'dart:io';

import 'package:fluvie_cli/src/stage_harness.dart';
import 'package:test/test.dart';

const _source = '// GENERATED\nvoid main() {}\n';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fluvie_stage_');
    addTearDown(() {
      if (project.existsSync()) project.deleteSync(recursive: true);
    });
  });

  group('stageHarness', () {
    test('writes the harness into <projectDir>/<relativeDir>', () {
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie/hero_dart',
      );

      expect(staged.dir.path, '${project.path}/.fluvie/hero_dart');
      expect(File('${staged.dir.path}/harness_test.dart').readAsStringSync(), _source);
    });

    test('writes the extra files beside the harness', () {
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie_playground/abc',
        extraFiles: const {'input.dart': 'Video build() => throw 0;'},
      );

      expect(
        File('${staged.dir.path}/input.dart').readAsStringSync(),
        'Video build() => throw 0;',
      );
    });

    test("harnessPath is relative to the project, which is flutter test's cwd", () {
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie/hero_dart',
      );

      expect(staged.harnessPath, '.fluvie/hero_dart/harness_test.dart');
      expect(File('${project.path}/${staged.harnessPath}').existsSync(), isTrue);
      expect(staged.projectDir, project.path);
    });

    test('creates the staging directory tree when it does not exist', () {
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie/deeply/nested/slug',
      );

      expect(staged.dir.existsSync(), isTrue);
    });

    test('restaging the same directory overwrites the harness', () {
      // The non-ephemeral directory is deterministic, so a re-render of the same
      // target rewrites it rather than piling up.
      stageHarness(
        projectDir: project.path,
        harnessSource: '// old\n',
        relativeDir: '.fluvie/hero_dart',
        ephemeral: false,
      );
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie/hero_dart',
        ephemeral: false,
      );

      expect(File('${staged.dir.path}/harness_test.dart').readAsStringSync(), _source);
    });

    test('staging is ephemeral by default', () {
      expect(
        stageHarness(
          projectDir: project.path,
          harnessSource: _source,
          relativeDir: '.fluvie_playground/abc',
        ).ephemeral,
        isTrue,
      );
    });
  });

  group('StagedHarness.cleanup', () {
    test('an ephemeral staging is deleted', () {
      // Two untrusted Playground submissions must never share a directory, so
      // the render owns its directory and takes it with it.
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie_playground/abc',
        extraFiles: const {'input.dart': 'Video build() => throw 0;'},
      );
      expect(staged.dir.existsSync(), isTrue);

      staged.cleanup();

      expect(staged.dir.existsSync(), isFalse);
    });

    test('a non-ephemeral staging survives, so the kernel cache hits next time', () {
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie/hero_dart',
        ephemeral: false,
      )..cleanup();

      expect(staged.dir.existsSync(), isTrue);
      expect(File('${staged.dir.path}/harness_test.dart').existsSync(), isTrue);
    });

    test('is a no-op when the directory is already gone', () {
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie_playground/abc',
      )..dir.deleteSync(recursive: true);

      expect(staged.cleanup, returnsNormally);
    });

    test('cleaning twice is a no-op', () {
      final staged = stageHarness(
        projectDir: project.path,
        harnessSource: _source,
        relativeDir: '.fluvie_playground/abc',
      )..cleanup();

      expect(staged.cleanup, returnsNormally);
    });
  });

  group('uniqueStageId', () {
    test('two ids never collide', () {
      expect(uniqueStageId(), isNot(uniqueStageId()));
    });

    test('is a non-empty path-safe token', () {
      expect(uniqueStageId(), matches(RegExp(r'^[a-z0-9]+$')));
    });

    test('a hundred ids in a row are all distinct', () {
      expect(List.generate(100, (_) => uniqueStageId()).toSet(), hasLength(100));
    });
  });
}
