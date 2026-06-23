// End-to-end Playground code render: a tiny real `Video build()` snippet is
// staged (input.dart + a generated harness), JIT-compiled and captured by a real
// `flutter test`, then encoded to an mp4 by a real ffmpeg — the whole untrusted
// code path the server runs.
//
// Tagged `render` so it stays OUT of the default `dart test`/`gate`: it needs a
// Flutter SDK, an ffmpeg binary, and the example render project. CI gates the
// tag per platform. This file must COMPILE everywhere even when it cannot run.
@Tags(['render'])
@Timeout(Duration(minutes: 20))
library;

import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show resolveProjectDir;
import 'package:fluvie_server/src/api/render/pipeline_render_runner.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:test/test.dart';

const _tinyVideo = '''
import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

Video build() => Video(
  width: 64,
  height: 64,
  fps: 12,
  scenes: [
    Scene(
      duration: Time.frames(6),
      children: const [Text('hi')],
    ),
  ],
);
''';

void main() {
  test('renders a submitted Video build() snippet to an mp4', () async {
    final project = resolveProjectDir();
    final workDir = Directory.systemTemp.createTempSync('fluvie_code_e2e_');
    addTearDown(() {
      if (workDir.existsSync()) workDir.deleteSync(recursive: true);
    });

    final runner = PipelineRenderRunner(renderProject: project);
    final outcome = await runner.run(
      const CodeRenderRequest(
        _tinyVideo,
        (format: null, aspect: null, quality: null, poster: null),
      ),
      workDir: workDir,
    );

    expect(outcome.videoContentType, 'video/mp4');
    final video = File(outcome.videoPath);
    expect(video.existsSync(), isTrue, reason: 'the encode should have produced an mp4');
    expect(video.lengthSync(), greaterThan(0));

    // The per-render staging directory is cleaned up after the render.
    expect(Directory('$project/.fluvie_playground').listSync(), isEmpty);
  });
}
