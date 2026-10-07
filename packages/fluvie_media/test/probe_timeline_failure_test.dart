import 'dart:convert';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  for (final report in <Object?>[
    [],
    {},
    {'frames': <Object?>[]},
    {
      'frames': [null],
    },
    {
      'frames': [
        {'pts_time': 'NaN'},
      ],
    },
    {
      'frames': [
        {'pts_time': '1'},
        {'pts_time': '0'},
      ],
    },
    {
      'frames': [
        {'pts_time': '1'},
      ],
    },
    {
      'frames': [
        {'pts_time': '0', 'duration_time': '0.1'},
        null,
      ],
    },
    {
      'frames': [
        {'pts_time': '0'},
        {'pts_time': '0'},
      ],
    },
  ]) {
    test('malformed decoded display index is an actionable media error ($report)', () async {
      final tools = _tools(jsonEncode(report));
      await expectLater(
        tools.probeTimeline('/fixture/broken.mp4'),
        throwsA(
          isA<MediaProcessException>()
              .having((error) => error.message, 'source', contains('broken.mp4'))
              .having((error) => error.message, 'display clock', contains('display timing')),
        ),
      );
    });
  }

  test('invalid JSON and native index failures preserve the source', () async {
    await expectLater(
      _tools('not JSON').probeTimeline('cat.mp4'),
      throwsA(isA<MediaProcessException>()),
    );
    final tools = FfmpegMediaTools(
      runner: (_, _, {workingDirectory}) async => (exitCode: 7, stdout: '', stderr: 'bad codec'),
    );
    addTearDown(tools.closeAsync);
    await expectLater(
      tools.probeTimeline('cat.mp4'),
      throwsA(
        isA<MediaProcessException>()
            .having((error) => error.exitCode, 'status', 7)
            .having((error) => error.stderr, 'diagnostic', 'bad codec'),
      ),
    );
  });

  test('stream duration supplies the final interval on the source clock', () async {
    final tools = _tools(
      jsonEncode({
        'frames': [
          {'pts_time': '5'},
          {'pts_time': '5.1'},
        ],
        'streams': [
          {'duration': '0.4', 'start_time': '5'},
        ],
        'format': {'start_time': '5'},
      }),
    );
    final timeline = await tools.probeTimeline('cat.mp4');
    expect(timeline.frameCount, 2);
    expect(timeline.durationSeconds, 0.4);
    expect(timeline.frameAt(0.39), 1);
  });

  test('unavailable stream duration repeats the final positive display interval', () async {
    final tools = _tools(
      jsonEncode({
        'frames': [
          {'pts_time': '5'},
          {'pts_time': '5.1'},
          {'pts_time': '5.4'},
        ],
        'streams': [
          {'duration': 'N/A'},
        ],
        'format': {'start_time': 'N/A'},
      }),
    );
    final timeline = await tools.probeTimeline('cat.mp4');
    expect(timeline.durationSeconds, 0.7);
    expect(timeline.frameAt(0.69), 2);
  });
}

FfmpegMediaTools _tools(String report) {
  final tools = FfmpegMediaTools(
    runner: (_, _, {workingDirectory}) async => (exitCode: 0, stdout: report, stderr: ''),
  );
  addTearDown(tools.closeAsync);
  return tools;
}
