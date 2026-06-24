@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 10))
library;

// End-to-end: drive the real fluvie CLI to render the quickstart composition,
// then ffprobe the file. Needs flutter, ffmpeg, and ffprobe on PATH, so it is
// ffmpeg-tagged and excluded from the default suite.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fluvie render whisker_standup produces a valid H.264 MP4', () async {
    final outDir = Directory('${Directory.systemTemp.path}/cli_quickstart_e2e')
      ..createSync(recursive: true);
    final out = '${outDir.path}/whisker.mp4';

    final result = await Process.run('dart', [
      'run',
      'fluvie_cli:fluvie',
      'render',
      'whisker_standup',
      '--out',
      out,
      '--frames',
      '24',
      '--verbose',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final file = File(out);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));

    final probe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_streams',
      out,
    ]);
    expect(probe.exitCode, 0, reason: probe.stderr.toString());
    final report = jsonDecode(probe.stdout as String) as Map<String, Object?>;
    final streams = (report['streams']! as List<Object?>).cast<Map<String, Object?>>();
    final video = streams.firstWhere((s) => s['codec_type'] == 'video');
    expect(video['codec_name'], 'h264');
    expect(video['nb_frames'], '24');
  });
}
