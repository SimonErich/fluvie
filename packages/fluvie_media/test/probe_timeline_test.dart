import 'dart:convert';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test('native timeline uses decoded display PTS and the complete final interval', () async {
    final tools = FfmpegMediaTools(
      runner: (_, args, {workingDirectory}) async => (
        exitCode: 0,
        stdout: jsonEncode({
          'frames': [
            {'best_effort_timestamp_time': '5.000000', 'duration_time': '0.100000', 'key_frame': 1},
            {'best_effort_timestamp_time': '5.100000', 'duration_time': '0.300000'},
            {'best_effort_timestamp_time': '5.400000', 'duration_time': '0.500000'},
            {'best_effort_timestamp_time': '5.900000', 'duration_time': '0.100000'},
          ],
        }),
        stderr: '',
      ),
    );
    addTearDown(tools.close);
    final timeline = await tools.probeTimeline('/fixture/variable.mkv');
    expect(timeline.frameAt(0.35), 1);
    expect(timeline.frameAt(0.89), 2);
    expect(timeline.frameCount, 4);
    expect(timeline.durationSeconds, 1);
  });

  test('a source without presentation timestamps fails rather than using packet DTS', () async {
    final tools = FfmpegMediaTools(
      runner: (_, args, {workingDirectory}) async => (
        exitCode: 0,
        stdout: jsonEncode({
          'frames': [
            {'pkt_dts_time': '0', 'duration_time': '1'},
          ],
        }),
        stderr: '',
      ),
    );
    addTearDown(tools.close);
    await expectLater(
      tools.probeTimeline('/fixture/no-display-clock.mp4'),
      throwsA(isA<MediaProcessException>().having((e) => e.message, 'source', contains('display'))),
    );
  });
}
