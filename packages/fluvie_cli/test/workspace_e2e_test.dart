@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 25))
library;

import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:test/test.dart';

const _video = '''
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';

Video build() => Video(width: 16, height: 16, scenes: [
  Scene(duration: Time.frames(3), children: const [
    ColoredBox(color: Color(0xffff0000), child: SizedBox.expand()),
  ]),
]);
''';

void main() {
  test('HTTP sessions reuse the native engine and retire it before stale requests', () async {
    final project = await Directory.systemTemp.createTemp('fluvie_workspace_e2e_');
    addTearDown(() => project.delete(recursive: true));
    final pubspec = File('${project.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: workspace_fixture
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
      ..writeAsStringSync(_video);
    final resolved = await Process.run('flutter', ['pub', 'get'], workingDirectory: project.path);
    expect(resolved.exitCode, 0, reason: '${resolved.stdout}\n${resolved.stderr}');
    final pubspecBefore = pubspec.readAsBytesSync();
    final lock = File('${project.path}/pubspec.lock');
    final lockBefore = lock.readAsBytesSync();
    const runner = IoProcessRunner();
    final toolchain = await ensureFfmpegToolchain(runner, mode: 'system', allowDownload: false);
    final diagnostics = StringBuffer();
    final session = WorkspaceSession(
      target: FileTarget(projectDir: project.path, path: source.path, entry: 'build'),
      directory: Directory('${project.path}/build/workspace'),
      toolchain: toolchain,
      err: diagnostics,
      // This acceptance compiles two fresh engines on busy native CI hosts.
      workerStartupTimeout: const Duration(minutes: 10),
    );
    final server = await WorkspaceServer.start(session);
    addTearDown(server.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    Future<({int status, Map<String, Object?> body})> job(Map<String, Object?> input) async {
      final request = await client.postUrl(Uri.parse('${server.endpoint}/jobs'));
      request.headers
        ..contentType = ContentType.json
        ..set('X-Fluvie-Token', server.token);
      request.write(jsonEncode(input));
      final response = await request.close();
      return (
        status: response.statusCode,
        body: jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, Object?>,
      );
    }

    final first = await job({'operation': 'frame', 'frameIndex': 0});
    expect(first.status, HttpStatus.ok, reason: '$diagnostics\n${first.body}');
    final red = File(first.body['filePath']! as String).readAsBytesSync();
    final second = await job({'operation': 'frame', 'frameIndex': 2});
    expect(second.status, HttpStatus.ok, reason: '$diagnostics\n${second.body}');
    expect(second.body['workerPid'], first.body['workerPid']);
    expect(second.body['sourceRevision'], first.body['sourceRevision']);
    expect(second.body['backend'], 'flutter-test');
    expect(second.body['comparison'], containsPair('frame', 0));
    expect(File(second.body['filePath']! as String).readAsBytesSync(), red);

    final inspection = await job({'operation': 'inspect'});
    expect(inspection.status, HttpStatus.ok, reason: '$diagnostics\n${inspection.body}');
    final facts = inspection.body['report']! as Map<String, Object?>;
    expect(facts['totalFrames'], 3);
    expect(facts['width'], 16);
    expect(facts['height'], 16);

    final review = await job({
      'operation': 'review',
      'reviewFrames': [0, 2],
      'reviewDeterminism': true,
      'strictQuality': true,
    });
    expect(review.status, HttpStatus.ok, reason: '$diagnostics\n${review.body}');
    expect(review.body['ok'], isTrue);
    final report = review.body['report']! as Map<String, Object?>;
    expect(report['samples'], hasLength(2));
    expect(report['determinism'], containsPair('ok', true));

    final render = await job({'operation': 'render', 'strictQuality': true});
    expect(render.status, HttpStatus.ok, reason: '$diagnostics\n${render.body}');
    expect(render.body['ok'], isTrue);
    expect(render.body['receipt'], isA<Map<String, Object?>>());
    expect(render.body['audioQuality'], containsPair('applicable', false));
    for (final result in [inspection, review, render]) {
      expect(result.body['workerPid'], first.body['workerPid']);
      expect(result.body['sourceRevision'], first.body['sourceRevision']);
    }
    final probe = await Process.run(toolchain.ffprobePath, [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-count_frames',
      '-show_entries',
      'stream=width,height,nb_read_frames',
      '-of',
      'json',
      render.body['filePath']! as String,
    ]);
    expect(probe.exitCode, 0, reason: '${probe.stderr}');
    final encoded = jsonDecode(probe.stdout as String) as Map<String, Object?>;
    final stream = (encoded['streams']! as List).single as Map<String, Object?>;
    expect(stream['width'], 16);
    expect(stream['height'], 16);
    expect(stream['nb_read_frames'], '3');

    source.writeAsStringSync(_video.replaceFirst('0xffff0000', '0xff00ff00'));
    final stale = await job({
      'operation': 'frame',
      'frameIndex': 0,
      'sourceRevision': first.body['sourceRevision'],
    });
    expect(stale.status, HttpStatus.conflict);
    expect(stale.body['error'], contains('Source revision changed'));
    expect(session.status['workerPid'], isNull);
    final revised = await job({'operation': 'frame', 'frameIndex': 0});
    expect(revised.status, HttpStatus.ok, reason: '$diagnostics\n${revised.body}');
    expect(revised.body['workerPid'], isNot(first.body['workerPid']));
    expect(revised.body['sourceRevision'], isNot(first.body['sourceRevision']));
    expect(File(revised.body['filePath']! as String).readAsBytesSync(), isNot(red));
    expect(pubspec.readAsBytesSync(), pubspecBefore);
    expect(lock.readAsBytesSync(), lockBefore);
    expect(Directory('${project.path}/test').existsSync(), isFalse);
    expect(Directory('${project.path}/.fluvie').existsSync(), isFalse);
  });
}
