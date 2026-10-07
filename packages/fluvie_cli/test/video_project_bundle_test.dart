import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('fluvie_bundle_test_');
    addTearDown(() => root.delete(recursive: true));
  });
  test('an unavailable publication directory cleans its private staging project', () async {
    final temp = Directory('${root.path}/temp')..createSync();
    File('${root.path}/blocked').writeAsStringSync('Keep this file.');
    final script = File('${root.path}/failed_publication.dart')
      ..writeAsStringSync(r'''
import 'dart:io';
import 'package:fluvie_cli/fluvie_cli.dart';

Future<void> main(List<String> args) async {
  try {
    await VideoProjectBundle.create(
      target: FileTarget(projectDir: args.single, path: '${args.single}/video.dart', entry: 'build'),
      output: '${args.single}/blocked/video.zip',
    );
  } on FileSystemException {
    return;
  }
  throw StateError('Expected the blocked output directory to fail.');
}
''');
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['--packages=${p.absolute('../../.dart_tool/package_config.json')}', script.path, root.path],
      environment: {'TMPDIR': temp.path},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(temp.listSync(), isEmpty);
    expect(File('${root.path}/blocked').readAsStringSync(), 'Keep this file.');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('portable bundle relocates path dependencies, assets, font and pinned lock', () async {
    final project = Directory('${root.path}/original')..createSync();
    final dependency = Directory('${root.path}/local')..createSync();
    File(
      '${dependency.path}/pubspec.yaml',
    ).writeAsStringSync('name: fluvie\nresolution: workspace\n');
    File('${dependency.path}/lib/fluvie.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('library;');
    File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: demo
resolution: workspace
dependencies:
  fluvie: {path: ${dependency.path}}
flutter:
  fonts:
    - family: Fixture
      fonts:
        - asset: type/fixture.ttf
''');
    File(
      '${project.path}/pubspec.lock',
    ).writeAsStringSync('packages:\n  fluvie:\n    source: path\n');
    final entry = File('${project.path}/lib/video.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('Video build() => video;');
    for (final resource in ['assets/cat.png', 'type/fixture.ttf']) {
      File('${project.path}/$resource')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
    }
    File('${project.path}/.env').writeAsStringSync('SECRET=never bundle');
    File('${project.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'packages': [
            {'name': 'demo', 'rootUri': project.uri.toString()},
            {'name': 'fluvie', 'rootUri': dependency.uri.toString()},
          ],
        }),
      );
    final zip = '${root.path}/video.zip';
    final manifest = await VideoProjectBundle.create(
      target: FileTarget(projectDir: project.path, path: entry.path, entry: 'build'),
      output: zip,
      settings: const {'aspect': 'square'},
    );
    expect(manifest['entry'], 'project/lib/video.dart');
    final restored = '${root.path}/restored';
    await project.delete(recursive: true);
    await dependency.delete(recursive: true);
    final replay = await VideoProjectBundle.unpack(zip, restored);
    expect(replay['verified'], isTrue);
    expect(File('$restored/project/assets/cat.png').existsSync(), isTrue);
    expect(File('$restored/project/type/fixture.ttf').existsSync(), isTrue);
    final pubspec = File('$restored/project/pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('../vendor/fluvie'));
    expect(pubspec, isNot(contains('resolution: workspace')));
    expect(File('$restored/project/.env').existsSync(), isFalse);
    expect(p.isWithin(restored, '$restored/${replay['entry']}'), isTrue);
  });

  test('archive traversal, duplicate entries and altered bytes are rejected atomically', () async {
    for (final archive in [
      Archive()..addFile(ArchiveFile.string('../escaped', 'bad')),
      Archive()
        ..addFile(ArchiveFile.string('bundle.json', '{}'))
        ..addFile(ArchiveFile.string('BUNDLE.JSON', '{}')),
      Archive()
        ..addFile(
          ArchiveFile.string(
            'bundle.json',
            jsonEncode({
              'schemaVersion': 1,
              'entry': 'project/lib/video.dart',
              'entryFunction': 'build',
              'settings': <String, Object?>{},
              'sourceRevision': 'a' * 64,
              'files': [
                {'path': 'project/lib/video.dart', 'byteLength': 3, 'sha256': 'incorrect'},
              ],
            }),
          ),
        )
        ..addFile(ArchiveFile.string('project/lib/video.dart', 'bad')),
    ]) {
      final zip = File('${root.path}/bad.zip')..writeAsBytesSync(ZipEncoder().encode(archive));
      final destination = '${root.path}/destination';
      await expectLater(
        VideoProjectBundle.unpack(zip.path, destination),
        throwsA(isA<CliFailure>()),
      );
      expect(Directory(destination).existsSync(), isFalse);
      expect(File('${root.path}/escaped').existsSync(), isFalse);
    }
  });
}
