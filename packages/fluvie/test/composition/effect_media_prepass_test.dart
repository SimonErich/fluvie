import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';

void main() {
  test('effects preserve nested media, clip plans, embedded audio and registration', () {
    final spec = VideoSpec.fromJson({
      'fluvieSpec': 1,
      'fps': 30,
      'size': {'width': 320, 'height': 180},
      'scenes': [
        {
          'duration': '120f',
          'children': [
            {
              'id': 'group',
              'type': 'Group',
              'effects': [
                {'kind': 'blur', 'sigma': 2},
              ],
              'children': [
                {
                  'id': 'clip',
                  'type': 'Clip',
                  'source': {'kind': 'asset', 'value': 'movie.mp4'},
                  'show': {'from': '30f', 'to': '90f'},
                  'effects': [
                    {'kind': 'grade', 'exposure': 0.5},
                  ],
                },
                {
                  'id': 'image',
                  'type': 'Image',
                  'source': {'kind': 'asset', 'value': 'still.png'},
                  'effects': [
                    {'kind': 'grain', 'amount': 0.1},
                  ],
                },
              ],
            },
          ],
        },
      ],
    });
    final video = spec.build();
    expect(
      collectCompositionMedia(video),
      containsAll([
        const MediaSource.asset('movie.mp4'),
        const MediaSource.asset('still.png'),
      ]),
    );
    final plans = collectClipPlans(
      video.scenes,
      video.fps,
      sceneStartFrames: video.sceneStartFrames,
    );
    expect(plans, hasLength(1));
    expect((plans.single.windowStart, plans.single.windowLength), (30, 60));
    final audio = collectClipAudioPlans(
      video.scenes,
      video.fps,
      sceneStartFrames: video.sceneStartFrames,
    );
    expect(audio, hasLength(1));
    expect((audio.single.startFrame, audio.single.windowFrames), (30, 60));
    final element = introspectTimeline(video).elementById('clip');
    expect(element, isNotNull);
  });
}
