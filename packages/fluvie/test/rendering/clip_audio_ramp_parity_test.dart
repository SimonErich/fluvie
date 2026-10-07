import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/rendering/clip_audio_staging.dart';

import 'fakes/fake_media_resolver.dart';

void main() {
  test(
    'retimed delayed clip audio keeps exact source phase and its own fade window on every backend',
    () async {
      final video = VideoSpec.fromJson(const {
        'fluvieSpec': 1,
        'fps': 30,
        'size': {'width': 100, 'height': 100},
        'scenes': [
          {
            'duration': '5s',
            'children': [
              {
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'clip.mp4'},
                'show': {'from': '2s', 'to': '3s'},
                'trim': {'from': '0.12345s', 'to': '3s'},
                'speed': {
                  'values': [0.5, 2.0],
                  'positions': ['0r', '1r'],
                },
                'fadeIn': '0.5r',
                'fadeOut': '4s',
                'automation': {'volume': 0.75},
              },
            ],
          },
        ],
      }).build();
      const metadata = (
        fps: 30000 / 1001,
        frameCount: 300,
        width: 100,
        height: 100,
        hasAudio: true,
      );
      final track = resolveAudioMix(
        video: video,
        fps: 30,
        totalFrames: 150,
        clipMetadata: (_) => metadata,
      ).tracks.single;
      expect(track.delayMs, 2000);
      expect(track.timeMap!.durationSeconds, 1);
      expect(track.timeMap!.sourceSeconds.last, closeTo(1.25, 1e-12));
      expect(track.trimStartSeconds, closeTo(0.12345, 1e-12));
      expect(track.trimEndSeconds, closeTo(1.37345, 1e-12));
      expect(
        track.fadeInSeconds,
        0.5,
        reason: 'Relative fades use the one-second clip, not the five-second video',
      );
      expect(
        track.fadeOutStartSeconds,
        2,
        reason: 'A long fade begins at its clip, never before it',
      );

      final directory = await Directory.systemTemp.createTemp('fluvie_clip_ramp_parity_');
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/clip.mp4');
      await source.writeAsBytes([1, 2, 3]);
      const mediaSource = MediaSource.asset('clip.mp4');
      final resolver = FakeMediaResolver(
        const {},
        metadata: {mediaSource: metadata},
        audioPaths: {const AudioSource.asset('clip.mp4'): source.path},
      );
      await resolver.preResolveAudio([const AudioSource.asset('clip.mp4')]);
      final sandbox = await Directory('${directory.path}/sandbox').create();
      final nodes = await stageClipAudio(
        plans: collectClipAudioPlans(video.scenes, 30, sceneStartFrames: video.sceneStartFrames),
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 150,
      );
      final fromNeutral = AudioTrackNode.fromResolved(track, name: nodes.single.name);
      expect(
        nodes.single.filterChain(inputIndex: 0, label: 'out'),
        fromNeutral.filterChain(inputIndex: 0, label: 'out'),
      );
    },
  );
}
