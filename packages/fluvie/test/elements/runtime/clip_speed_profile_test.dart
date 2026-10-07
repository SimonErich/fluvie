import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
import 'package:fluvie/src/elements/runtime/clip_speed_profile.dart';

void main() {
  test('a linear ramp integrates source time instead of multiplying instantaneous rate', () {
    final ramp = KeyframedNumber.linear(
      values: const [1, 3],
      positions: const [Time.relative(0), Time.relative(1)],
    );
    final map = integrateClipSpeedRamp(ramp, fps: 30, windowFrames: 60);
    expect(map, hasLength(61));
    expect(map[30], closeTo(1.5, 1e-12));
    expect(map[60], closeTo(4, 1e-12));
    expect(
      resampleClipFrame(
        compFrame: 30,
        windowStart: 0,
        compFps: 30,
        srcFps: 30,
        trimStartFrames: 10,
        trimEndFrames: 300,
        sourceTimeMap: map,
      ),
      55,
    );
    expect(
      planClipFrames(
        windowStart: 0,
        windowLength: 31,
        compFps: 30,
        srcFps: 30,
        trimStartFrames: 10,
        trimEndFrames: 300,
        sourceTimeMap: map,
      ).last,
      55,
    );
  });
  test('a ramp crossing zero and a reversed ramp are refused', () {
    for (final values in [
      [1.0, -1.0],
      [-2.0, -1.0],
      [0.0, 1.0],
    ]) {
      final ramp = KeyframedNumber.linear(
        values: values,
        positions: const [Time.relative(0), Time.relative(1)],
      );
      expect(
        () => integrateClipSpeedRamp(ramp, fps: 30, windowFrames: 60),
        throwsA(isA<FluvieSpecError>()),
      );
    }
  });
  test('speed ramp spec round trips and picture/audio plans share one map', () {
    final spec = VideoSpec.fromJson({
      'fluvieSpec': 1,
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'id': 'clip',
              'type': 'Clip',
              'source': {'kind': 'asset', 'value': 'clip.mp4'},
              'speed': {
                'values': [1, 3],
                'positions': ['0r', '1r'],
              },
            },
          ],
        },
      ],
    });
    expect(VideoSpec.fromJson(spec.toJson()).toJson(), spec.toJson());
    final video = spec.build();
    final picture = collectClipPlans(video.scenes, 30, sceneStartFrames: [0]).single;
    final audio = collectClipAudioPlans(video.scenes, 30, sceneStartFrames: [0]).single;
    expect(picture.sourceTimeMap, same(audio.sourceTimeMap));
    expect(picture.sourceTimeMap!.last, closeTo(4, 1e-12));
    final raw = spec.toJson();
    final scene = (raw['scenes']! as List<Object?>).first! as Map<String, Object?>;
    final clip = (scene['children']! as List<Object?>).first! as Map<String, Object?>;
    clip['speed'] = {
      'values': [1, -1],
      'positions': ['0r', '1r'],
    };
    expect(() => VideoSpec.fromJson(raw), throwsA(isA<FluvieSpecError>()));
  });
}
