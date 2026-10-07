import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:fluvie_media/native.dart';

void main() {
  test('default probing supplies display timing for variable-rate footage', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_probe_pts_');
    addTearDown(() => directory.delete(recursive: true));
    final tools = FfmpegMediaTools();
    addTearDown(tools.closeAsync);
    final output = '${directory.path}/variable.mkv';
    final encoded = await tools.run(tools.ffmpegPath, [
      '-v',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=16x8:rate=10',
      '-frames:v',
      '4',
      '-vf',
      r'settb=1/1000,setpts=if(eq(N\,0)\,0\,if(eq(N\,1)\,100\,if(eq(N\,2)\,400\,900)))',
      '-fps_mode',
      'vfr',
      '-c:v',
      'ffv1',
      output,
    ]);
    expect(encoded.exitCode, 0, reason: encoded.stderr);
    final facts = await const FfprobeVideoProbeService().probe(output);
    expect(facts.timeline?.frameAt(.35), 1);
    expect(facts.timeline?.frameAt(.89), 2);
    expect(facts.timeline?.durationSeconds, 1);
    expect(facts.nbFrames, 4);
  }, skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1');
}
