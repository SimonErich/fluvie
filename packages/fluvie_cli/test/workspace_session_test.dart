@Tags(['ffmpeg'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/workspace_session.dart';
import 'package:test/test.dart';

void main() {
  test('frames carry revision and latency, preserve comparison and reject stale edits', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_workspace_test_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/lib/video.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('Video build() => video;');
    File('${root.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    var changeDuringCapture = false;
    final session = WorkspaceSession(
      target: FileTarget(projectDir: root.path, path: source.path, entry: 'build'),
      directory: Directory('${root.path}/build/workspace'),
      toolchain: const FfmpegToolchain(
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
        build: 'test',
        ffmpegVersion: 'test',
        ffprobeVersion: 'test',
      ),
      err: StringBuffer(),
      capture: (invocation) async {
        final out = invocation['outputDir']! as String;
        File('$out/frame.png').writeAsBytesSync([1, 2, 3]);
        File('$out/render-result.json').writeAsStringSync(
          jsonEncode({
            'schemaVersion': 1,
            'kind': 'frame',
            'filePath': '$out/frame.png',
          }),
        );
        if (changeDuringCapture) source.writeAsStringSync('changed during capture');
        return {'elapsedMilliseconds': 12};
      },
    );
    addTearDown(session.close);
    final first = await session.execute({'operation': 'frame', 'frameIndex': 0});
    expect(first['backend'], 'flutter-test');
    expect(first['sourceRevision'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(first['captureMilliseconds'], 12);
    expect(File(first['filePath']! as String).existsSync(), isTrue);
    source.writeAsStringSync('Video build() => revisedVideo;');
    final second = await session.execute({'operation': 'frame', 'frameIndex': 0});
    expect(second['sourceRevision'], isNot(first['sourceRevision']));
    expect(second['comparison'], isNotNull);
    changeDuringCapture = true;
    await expectLater(
      session.execute({'operation': 'frame'}),
      throwsA(predicate((e) => '$e'.contains('changed'))),
    );
    await expectLater(session.execute({'operation': 'shell'}), throwsArgumentError);
    await expectLater(
      session.execute({'operation': 'frame', 'frameIndex': -1}),
      throwsArgumentError,
    );
  });
}
