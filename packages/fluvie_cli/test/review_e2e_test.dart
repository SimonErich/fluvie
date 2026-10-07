@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const _stable = '''
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';

Video build() => Video(
  width: 16,
  height: 16,
  scenes: [
    Scene(duration: Time.frames(3), children: const [
      ColoredBox(color: Color(0xffff0000), child: SizedBox.expand()),
    ]),
  ],
);
''';

const _changingFactory = '''
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';

int builds = 0;
Video build() => Video(
  width: 16,
  height: 16,
  scenes: [
    Scene(duration: Time.frames(3), children: [
      ColoredBox(
        color: ++builds == 1 ? const Color(0xffff0000) : const Color(0xff00ff00),
        child: const SizedBox.expand(),
      ),
    ]),
  ],
);
''';

void main() {
  test(
    'managed review remounts and re-evaluates the entry without consumer harness files',
    () async {
      final cli = Directory.current.absolute.path;
      final project = Directory.systemTemp.createTempSync('fluvie_review_e2e_');
      addTearDown(() => project.deleteSync(recursive: true));
      final pubspec = File('${project.path}/pubspec.yaml')
        ..writeAsStringSync('''
name: review_fixture
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  flutter: {sdk: flutter}
  fluvie:
    path: ${Directory.current.parent.path}/fluvie
dependency_overrides:
  fluvie_media:
    path: ${Directory.current.parent.path}/fluvie_media
dev_dependencies:
  flutter_test: {sdk: flutter}
''');
      final source = File('${project.path}/lib/video.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(_stable);
      final resolved = await Process.run('flutter', ['pub', 'get'], workingDirectory: project.path);
      expect(resolved.exitCode, 0, reason: '${resolved.stdout}\n${resolved.stderr}');
      final pubspecBefore = pubspec.readAsBytesSync();
      final lock = File('${project.path}/pubspec.lock');
      final lockBefore = lock.readAsBytesSync();
      Future<ProcessResult> review(String output) => Process.run('dart', [
        '$cli/bin/fluvie.dart',
        'review',
        source.path,
        '--determinism',
        '--samples',
        '0,2',
        '--toolchain',
        'system',
        '--out-dir',
        '${project.path}/$output',
        '--json',
      ], workingDirectory: cli);

      final stable = await review('stable');
      expect(stable.exitCode, 0, reason: '${stable.stdout}\n${stable.stderr}');
      final stableReport = jsonDecode(stable.stdout as String) as Map<String, Object?>;
      final stableCheck = stableReport['determinism']! as Map<String, Object?>;
      expect(stableCheck['ok'], true);
      expect((stableCheck['checks']! as List).last, containsPair('factoryEvaluated', true));
      expect(stableReport['samples'], hasLength(2));

      source.writeAsStringSync(_changingFactory);
      final changed = await review('changed');
      expect(changed.exitCode, 1, reason: '${changed.stdout}\n${changed.stderr}');
      final changedReport = jsonDecode(changed.stdout as String) as Map<String, Object?>;
      expect(changedReport['stage'], 'complete', reason: '${changed.stdout}\n${changed.stderr}');
      final changedCheck = changedReport['determinism']! as Map<String, Object?>;
      expect(changedCheck['ok'], false);
      expect((changedCheck['checks']! as List).first, containsPair('ok', true));
      expect(
        (changedCheck['mismatches']! as List).first,
        containsPair('code', 'fresh_mount_changes_pixels'),
      );
      expect(pubspec.readAsBytesSync(), pubspecBefore);
      expect(lock.readAsBytesSync(), lockBefore);
      expect(Directory('${project.path}/.fluvie').existsSync(), false);
      expect(Directory('${project.path}/test').existsSync(), false);
    },
  );
}
