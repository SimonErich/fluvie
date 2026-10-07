import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';

Map<String, Object?> deck({Map<String, Object?>? transition}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'lanes': [
    {'id': 'v1'},
  ],
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'a',
          'type': 'Clip',
          'lane': 'v1',
          'source': {'kind': 'asset', 'value': 'a.mp4'},
          'show': {'from': '0f', 'to': '60f'},
        },
        {
          'id': 'b',
          'type': 'Clip',
          'lane': 'v1',
          'source': {'kind': 'asset', 'value': 'b.mp4'},
          'show': {'from': '60f', 'to': '120f'},
        },
      ],
      'transitions': [
        transition ??
            {
              'between': ['a', 'b'],
              'kind': 'crossFade',
              'duration': '10f',
            },
      ],
    },
  ],
};
void main() {
  test('clip transition round trips and gives both picture plans the overlap', () {
    final spec = VideoSpec.fromJson(deck());
    expect(VideoSpec.fromJson(spec.toJson()).toJson(), spec.toJson());
    final video = spec.build();
    final plans = collectClipPlans(video.scenes, 30, sceneStartFrames: [0]);
    expect(plans.map((p) => (p.windowStart, p.windowLength)), [(0, 60), (50, 60)]);
    final timeline = introspectTimeline(video);
    expect(timeline.scenes.single.elementById('b')!.window.start, 50);
  });
  test('equal-power clip audio fades share the exact picture window', () {
    final video = VideoSpec.fromJson(deck()).build();
    final plans = collectClipAudioPlans(video.scenes, 30, sceneStartFrames: [0]);
    final a = plans[0].audio.automation.resolve(fps: 30, windowFrames: plans[0].windowFrames);
    final b = plans[1].audio.automation.resolve(fps: 30, windowFrames: plans[1].windowFrames);
    for (var frame = 50; frame <= 60; frame++) {
      final out = audioVolumeAt(a, frame / 30);
      final into = audioVolumeAt(b, (frame - 50) / 30);
      expect(out * out + into * into, closeTo(1, 1e-10));
    }
  });
  for (final entry in <String, Map<String, Object?>>{
    'unknown id': {
      'between': ['a', 'missing'],
      'kind': 'crossFade',
      'duration': '10f',
    },
    'self pairing': {
      'between': ['a', 'a'],
      'kind': 'crossFade',
      'duration': '10f',
    },
    'does not fit': {
      'between': ['a', 'b'],
      'kind': 'crossFade',
      'duration': '70f',
    },
    'zero duration': {
      'between': ['a', 'b'],
      'kind': 'crossFade',
      'duration': '0f',
    },
  }.entries) {
    test('refuses ${entry.key} before build', () {
      expect(
        () => VideoSpec.fromJson(deck(transition: entry.value)),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  }
  test('different lanes and gapped windows are refused before build', () {
    final lanes = deck();
    (lanes['lanes']! as List).add({'id': 'v2'});
    final children = ((lanes['scenes']! as List).single as Map)['children'] as List;
    (children[1] as Map)['lane'] = 'v2';
    expect(() => VideoSpec.fromJson(lanes), throwsA(isA<FluvieSpecError>()));
    (children[1] as Map)['lane'] = 'v1';
    (children[1] as Map)['show'] = {'from': '61f', 'to': '120f'};
    expect(() => VideoSpec.fromJson(lanes), throwsA(isA<FluvieSpecError>()));
  });
  test('stage table and retimed equal-power envelope use one overlap window', () {
    for (final duration in [5, 10, 20]) {
      final spec = VideoSpec.fromJson(
        deck(
          transition: {
            'between': ['a', 'b'],
            'kind': 'crossFade',
            'duration': '${duration}f',
          },
        ),
      );
      final layout = resolveElementTransitionLayout(
        children: spec.scenes.single.children,
        transitions: spec.scenes.single.transitions,
        fps: 30,
        durationFrames: 120,
      );
      final blend = layout.blends.single;
      for (var frame = 0; frame < 120; frame++) {
        expect(blend.contains(frame), frame >= 60 - duration && frame < 60);
        if (blend.contains(frame)) {
          expect(blend.progressAt(frame), (frame - 60 + duration + 1) / duration);
        }
      }
      final plans = collectClipAudioPlans(spec.build().scenes, 30, sceneStartFrames: [0]);
      expect(plans[1].startFrame, 60 - duration);
      final env = plans[1].audio.automation.resolve(fps: 30, windowFrames: plans[1].windowFrames);
      expect(audioVolumeAt(env, 0), 0);
      expect(audioVolumeAt(env, duration / 30), closeTo(1, 1e-10));
    }
  });
  test('same nested group is a valid clip transition holding list', () {
    final json = deck();
    final scene = (json['scenes']! as List).single! as Map<String, Object?>;
    scene['children'] = [
      {'id': 'group', 'type': 'Group', 'children': scene['children']},
    ];
    final video = VideoSpec.fromJson(json).build();
    final plans = collectClipPlans(video.scenes, 30, sceneStartFrames: [0]);
    expect(plans.map((p) => p.windowStart), [0, 50]);
  });
}
