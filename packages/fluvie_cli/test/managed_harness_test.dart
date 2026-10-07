import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_support.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _SupportRunner implements ProcessRunner {
  _SupportRunner(this.packages, this.graph);
  final List<Map<String, Object?>> packages;
  final List<Map<String, Object?>> graph;
  int calls = 0;
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls++;
    expect(executable, 'flutter');
    expect(args, ['pub', 'get']);
    final dir = Directory(p.join(workingDirectory!, '.dart_tool'))..createSync(recursive: true);
    File(
      p.join(dir.path, 'package_config.json'),
    ).writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': packages}));
    File(p.join(dir.path, 'package_graph.json')).writeAsStringSync(
      jsonEncode({
        'configVersion': 1,
        'roots': ['fluvie_render_support'],
        'packages': graph,
      }),
    );
    return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
  }
}

void main() {
  late Directory dir;
  late Directory project;
  late String cache;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('fluvie_managed_test_');
    project = Directory(p.join(dir.path, 'project'))..createSync();
    cache = p.join(dir.path, 'cache');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(
      'name: consumer\ndependencies:\n  flutter: {sdk: flutter}\n  fluvie: ^0.3.1\n',
    );
    addTearDown(() => dir.deleteSync(recursive: true));
  });
  Map<String, Object?> package(
    String name, {
    String version = '1.0.0',
    Map<String, String> dependencies = const {},
  }) {
    final root = Directory(p.join(dir.path, 'packages', name))..createSync(recursive: true);
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(
      jsonEncode({'name': name, 'version': version, 'dependencies': dependencies}),
    );
    return {
      'name': name,
      'rootUri': root.uri.toString(),
      'packageUri': 'lib/',
      'languageVersion': '3.12',
    };
  }

  File config(List<Map<String, Object?>> packages) {
    final file = File(p.join(project.path, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': packages}));
    File(p.join(file.parent.path, 'package_graph.json')).writeAsStringSync(
      jsonEncode({
        'configVersion': 1,
        'roots': ['consumer'],
        'packages': [
          {
            'name': 'consumer',
            'version': '1.0.0',
            'dependencies': ['fluvie', 'flutter'],
            'devDependencies': <String>[],
          },
          for (final entry in packages)
            {'name': entry['name'], 'version': '1.0.0', 'dependencies': <String>[]},
        ],
      }),
    );
    return file;
  }

  test(
    'normal staging uses consumer resolution, stays outside project and reuses adapter',
    () async {
      final consumerConfig = config([package('fluvie'), package('flutter_test')]);
      final targetFile = File(p.join(project.path, 'lib', 'video.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('Video build() => throw 0;');
      final target = resolveFileTarget(arg: targetFile.path, entry: 'build');
      final runner = _SupportRunner([], []);
      final first = await stageManagedHarness(
        projectDir: project.path,
        runner: runner,
        target: target,
        cacheRoot: cache,
      );
      final second = await stageManagedHarness(
        projectDir: project.path,
        runner: runner,
        target: target,
        cacheRoot: cache,
      );
      expect(first.harnessPath, second.harnessPath);
      expect(first.packageConfigPath, consumerConfig.path);
      expect(p.isWithin(project.path, first.harnessPath), isFalse);
      expect(
        File(first.harnessPath).readAsStringSync(),
        contains("import 'package:consumer/video.dart' as target;"),
      );
      expect(runner.calls, 0);
      expect(Directory(p.join(project.path, '.fluvie')).existsSync(), isFalse);
    },
  );

  test(
    'missing SDK support resolves once and preserves consumer package roots and graph',
    () async {
      final fluvie = package('fluvie');
      final flutter = package('flutter');
      final selected = package('test_api', version: '0.7.12');
      final consumerConfig = config([fluvie, flutter, selected]);
      final before = consumerConfig.readAsStringSync();
      final testSupport = package('flutter_test', dependencies: {'test_api': '0.7.12'});
      final runner = _SupportRunner(
        [fluvie, flutter, selected, testSupport],
        [
          {
            'name': 'flutter_test',
            'version': '0.0.0',
            'dependencies': ['test_api'],
          },
        ],
      );
      final overlay = await prepareRenderPackageConfig(
        projectDir: project.path,
        runner: runner,
        cacheRoot: cache,
      );
      final resolved = jsonDecode(File(overlay).readAsStringSync()) as Map<String, Object?>;
      final entries = (resolved['packages']! as List).cast<Map<String, Object?>>();
      expect(entries.singleWhere((e) => e['name'] == 'test_api')['rootUri'], selected['rootUri']);
      expect(entries.any((e) => e['name'] == 'flutter_test'), isTrue);
      final graph =
          jsonDecode(
                File(p.join(File(overlay).parent.path, 'package_graph.json')).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(
        (graph['packages']! as List).cast<Map<String, Object?>>().singleWhere(
          (e) => e['name'] == 'consumer',
        )['devDependencies'],
        contains('flutter_test'),
      );
      expect(consumerConfig.readAsStringSync(), before);
      expect(
        File(p.join(File(overlay).parent.parent.path, 'pubspec.yaml')).readAsStringSync(),
        File(p.join(project.path, 'pubspec.yaml')).readAsStringSync(),
      );
      expect(
        await prepareRenderPackageConfig(
          projectDir: project.path,
          runner: runner,
          cacheRoot: cache,
        ),
        overlay,
      );
      expect(runner.calls, 1);
    },
  );

  test('SDK-pinned dependency conflict fails instead of replacing the consumer version', () async {
    final fluvie = package('fluvie');
    final flutter = package('flutter');
    final selected = package('test_api', version: '0.7.11');
    final consumerConfig = config([fluvie, flutter, selected]);
    final before = consumerConfig.readAsStringSync();
    final testSupport = package('flutter_test', dependencies: {'test_api': '0.7.12'});
    final runner = _SupportRunner([fluvie, flutter, selected, testSupport], []);
    await expectLater(
      prepareRenderPackageConfig(projectDir: project.path, runner: runner, cacheRoot: cache),
      throwsA(
        predicate(
          (e) => e.toString().contains('test_api 0.7.12') && e.toString().contains('0.7.11'),
        ),
      ),
    );
    expect(consumerConfig.readAsStringSync(), before);
  });

  test('spec and built-in authoring share the external managed engine', () async {
    config([package('fluvie'), package('flutter_test'), package('fluvie_ai')]);
    final runner = _SupportRunner([], []);
    final spec = await stageManagedHarness(
      projectDir: project.path,
      runner: runner,
      spec: true,
      cacheRoot: cache,
    );
    final author = await stageManagedHarness(
      projectDir: project.path,
      runner: runner,
      author: true,
      cacheRoot: cache,
    );
    expect(File(spec.harnessPath).readAsStringSync(), contains('runFluvieRender('));
    expect(File(author.harnessPath).readAsStringSync(), contains('runFluvieRender('));
    expect(
      File(p.join(author.dir.path, 'input.dart')).readAsStringSync(),
      contains('LlmVideoAuthorService'),
    );
    expect(runner.calls, 0);
  });
}
