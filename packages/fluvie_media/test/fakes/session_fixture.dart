import 'dart:convert';
import 'dart:io';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

typedef SessionFixture = ({FfmpegMediaTools tools, Directory directory, File pid});

/// A real owned child with controllable pixels and a deterministic probe index.
Future<SessionFixture> sessionFixture({
  String body = 'sys.stdout.buffer.write(bytes([1, 2, 3, 255]) * 200)',
  int frames = 200,
  bool duplicateKeyTime = false,
  Duration timeout = const Duration(seconds: 2),
  int encodeExit = 0,
}) async {
  final directory = await Directory.systemTemp.createTemp('fluvie_session_behavior_');
  final decoder = File('${directory.path}/decoder.py');
  final pid = File('${directory.path}/decoder.pid');
  await decoder.writeAsString(
    '''
#!/usr/bin/env python3
import os, sys, time
with open(${jsonEncode(pid.path)}, 'w') as target:
    target.write(str(os.getpid()))
$body
'''
        .trimLeft(),
  );
  await Process.run('chmod', ['+x', decoder.path]);
  final tools = FfmpegMediaTools(
    ffmpegPath: decoder.path,
    ffprobePath: '/fixture/probe',
    timeout: timeout,
    runner: (executable, arguments, {workingDirectory}) async {
      if (executable != '/fixture/probe') {
        return (exitCode: encodeExit, stdout: '', stderr: 'fixture encoder refused output');
      }
      final report = arguments.contains('-show_frames')
          ? {
              'frames': [
                for (var index = 0; index < frames; index++)
                  {
                    'best_effort_timestamp_time':
                        ((duplicateKeyTime && index == 80 ? 79 : index) / 10).toString(),
                    'duration_time': '0.1',
                    'key_frame': index % 10 == 0 ? 1 : 0,
                  },
              ],
            }
          : {
              'streams': [
                {
                  'codec_type': 'video',
                  'codec_name': 'h264',
                  'width': 1,
                  'height': 1,
                  'avg_frame_rate': '10/1',
                  'nb_frames': '$frames',
                  'duration': '${frames / 10}',
                  'pix_fmt': 'yuv420p',
                },
              ],
            };
      return (exitCode: 0, stdout: jsonEncode(report), stderr: '');
    },
  );
  addTearDown(() async {
    await tools.closeAsync();
    await directory.delete(recursive: true);
  });
  return (tools: tools, directory: directory, pid: pid);
}
