import 'package:flutter_test/flutter_test.dart';

import 'package:fluvie/src/domain/audio_config.dart';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/encoding/ffmpeg_filter_graph_builder.dart';
import 'package:fluvie/src/presentation/audio_source.dart';
import 'package:fluvie/src/presentation/audio_track.dart';

void main() {
  group('AudioTrackConfig', () {
    test('serializes and deserializes correctly', () {
      const track = AudioTrackConfig(
        source: AudioSourceConfig(
          type: AudioSourceType.asset,
          uri: 'assets/audio.mp3',
        ),
        startFrame: 0,
        durationInFrames: 60,
        trimStartFrame: 15, // 0.5 seconds at 30fps
        trimEndFrame: 75, // 2.5 seconds at 30fps
        volume: 0.8,
        fadeInFrames: 10,
        fadeOutFrames: 15,
        loop: true,
      );

      final json = track.toJson();
      final deserialized = AudioTrackConfig.fromJson(json);

      expect(deserialized.source.type, AudioSourceType.asset);
      expect(deserialized.source.uri, 'assets/audio.mp3');
      expect(deserialized.startFrame, 0);
      expect(deserialized.durationInFrames, 60);
      expect(deserialized.trimStartFrame, 15);
      expect(deserialized.trimEndFrame, 75);
      expect(deserialized.volume, 0.8);
      expect(deserialized.fadeInFrames, 10);
      expect(deserialized.fadeOutFrames, 15);
      expect(deserialized.loop, isTrue);
    });

    test('converts frames to milliseconds correctly', () {
      const track = AudioTrackConfig(
        source: AudioSourceConfig(
          type: AudioSourceType.asset,
          uri: 'assets/audio.mp3',
        ),
        startFrame: 0,
        durationInFrames: 60,
        trimStartFrame: 30, // 1 second at 30fps
        trimEndFrame: 90, // 3 seconds at 30fps
      );

      expect(track.trimStartFrameToMs(30), 1000);
      expect(track.trimEndFrameToMs(30), 3000);
    });
  });

  group('AudioTrack widget', () {
    test('exposes AudioTrackConfig via toAudioConfig', () {
      final track = AudioTrack(
        source: AudioSource.asset('assets/loop.mp3'),
        startFrame: 45,
        durationInFrames: 120,
        trimStartFrame: 8, // ~250ms at 30fps
        trimEndFrame: 60, // 2 seconds at 30fps
        volume: 0.75,
        fadeInFrames: 15,
        fadeOutFrames: 30,
        loop: true,
      );

      final config = track.toAudioConfig();

      expect(config.source.type, AudioSourceType.asset);
      expect(config.source.uri, 'assets/loop.mp3');
      expect(config.startFrame, 45);
      expect(config.durationInFrames, 120);
      expect(config.trimStartFrame, 8);
      expect(config.trimEndFrame, 60);
      expect(config.volume, 0.75);
      expect(config.fadeInFrames, 15);
      expect(config.fadeOutFrames, 30);
      expect(config.loop, isTrue);
    });
  });

  group('FFmpegFilterGraphBuilder', () {
    test('builds audio filter graph with mix', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 300,
          width: 1080,
          height: 1920,
        ),
        sequences: const [],
        audioTracks: [
          const AudioTrackConfig(
            source: AudioSourceConfig(
              type: AudioSourceType.file,
              uri: '/tmp/audio.wav',
            ),
            startFrame: 30,
            durationInFrames: 90,
            fadeInFrames: 15,
            fadeOutFrames: 15,
            volume: 0.5,
          ),
        ],
      );

      final builder = FFmpegFilterGraphBuilder();
      final graph = builder.build(config);

      expect(graph.graph, contains('[0:v]'));
      // Single track goes directly to output without amix
      expect(graph.audioOutputLabel, '[a_mix_out]');
      expect(graph.videoOutputLabel, '[v_out]');
      expect(graph.graph, contains('adelay'));
    });
  });
}
