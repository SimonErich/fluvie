import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:test/test.dart';

void main() {
  test(
    'bundle refuses declared assets through symlink ancestors and enforces creation limits',
    () async {
      final root = await Directory.systemTemp.createTemp('fluvie_bundle_boundary_');
      addTearDown(() => root.delete(recursive: true));
      final project = Directory('${root.path}/project')..createSync();
      final entry = File('${project.path}/lib/video.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('Video build() => video;');
      final spec = File('${project.path}/pubspec.yaml')..writeAsStringSync('name: demo\n');
      File('${project.path}/pubspec.lock').writeAsStringSync('packages: {}\n');
      File('${project.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'packages': [
              {'name': 'demo', 'rootUri': project.uri.toString()},
            ],
          }),
        );
      final target = FileTarget(projectDir: project.path, path: entry.path, entry: 'build');
      final output = '${root.path}/video.zip';
      await expectLater(
        VideoProjectBundle.create(target: target, output: output, maxBytes: 1),
        throwsA(isA<CliFailure>()),
      );
      expect(File(output).existsSync(), isFalse);
      await VideoProjectBundle.create(target: target, output: output);
      final inspected = await VideoProjectBundle.inspect(output);
      expect(inspected['verified'], isTrue);
      expect(inspected.containsKey('directory'), isFalse);
      await expectLater(
        VideoProjectBundle.unpack(output, '${root.path}/over-budget', maxBytes: 1),
        throwsA(isA<CliFailure>()),
      );
      expect(Directory('${root.path}/over-budget').existsSync(), isFalse);
      if (!Platform.isWindows) {
        final outside = Directory('${root.path}/outside')..createSync();
        File('${outside.path}/private.bin').writeAsStringSync('private');
        Link('${project.path}/linked').createSync(outside.path);
        spec.writeAsStringSync('name: demo\nflutter:\n  assets:\n    - linked/private.bin\n');
        await expectLater(
          VideoProjectBundle.create(target: target, output: '${root.path}/escape.zip'),
          throwsA(isA<CliFailure>()),
        );
        expect(File('${root.path}/escape.zip').existsSync(), isFalse);
      }
    },
  );
}
