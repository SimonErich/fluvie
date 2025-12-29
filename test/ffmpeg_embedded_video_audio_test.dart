import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/encoding/ffmpeg_filter_graph_builder.dart';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/domain/embedded_video_config.dart';
import 'package:fluvie/src/domain/audio_config.dart';

void main() {
  group('FFmpegFilterGraphBuilder embedded video audio', () {
    test('builds audio filter for embedded video with includeAudio=true', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 300,
          width: 1080,
          height: 1920,
        ),
        sequences: [],
        audioTracks: [],
        embeddedVideos: [
          EmbeddedVideoConfig(
            videoPath: 'test.mp4',
            startFrame: 100,
            durationInFrames: 150,
            trimStartSeconds: 0,
            width: 900,
            height: 500,
            includeAudio: true,
            audioVolume: 1.0,
            audioFadeInFrames: 0,
            audioFadeOutFrames: 0,
            id: 'test_video',
          ),
        ],
      );

      final builder = FFmpegFilterGraphBuilder();
      final graph = builder.build(config);

      // Should have audio output
      expect(graph.audioOutputLabel, equals('[a_mix_out]'));

      // Graph should contain audio filter for embedded video
      expect(graph.graph, contains('[1:a]'));
      expect(graph.graph, contains('atrim=start=0:end=5'));
      expect(graph.graph, contains('adelay=3333'));
    });

    test('includes audio from embedded video with volume adjustment', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 300,
          width: 1080,
          height: 1920,
        ),
        sequences: [],
        audioTracks: [],
        embeddedVideos: [
          EmbeddedVideoConfig(
            videoPath: 'test.mp4',
            startFrame: 60,
            durationInFrames: 120,
            trimStartSeconds: 2.0,
            width: 900,
            height: 500,
            includeAudio: true,
            audioVolume: 0.8,
            audioFadeInFrames: 15,
            audioFadeOutFrames: 30,
            id: 'test_video',
          ),
        ],
      );

      final builder = FFmpegFilterGraphBuilder();
      final graph = builder.build(config);

      expect(graph.audioOutputLabel, equals('[a_mix_out]'));
      expect(graph.graph, contains('[1:a]'));
      expect(graph.graph, contains('volume=0.8'));
      expect(graph.graph, contains('afade=t=in'));
      expect(graph.graph, contains('afade=t=out'));
    });

    test('mixes embedded video audio with separate audio track', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 300,
          width: 1080,
          height: 1920,
        ),
        sequences: [],
        audioTracks: [
          AudioTrackConfig(
            source: AudioSourceConfig(
              type: AudioSourceType.asset,
              uri: 'assets/music.mp3',
            ),
            startFrame: 0,
            durationInFrames: 300,
          ),
        ],
        embeddedVideos: [
          EmbeddedVideoConfig(
            videoPath: 'test.mp4',
            startFrame: 100,
            durationInFrames: 150,
            trimStartSeconds: 0,
            width: 900,
            height: 500,
            includeAudio: true,
            audioVolume: 1.0,
            audioFadeInFrames: 0,
            audioFadeOutFrames: 0,
            id: 'test_video',
          ),
        ],
      );

      final builder = FFmpegFilterGraphBuilder();
      final graph = builder.build(config);

      // Should have both audio sources mixed
      expect(graph.audioOutputLabel, equals('[a_mix_out]'));
      expect(graph.graph, contains('[1:a]')); // Embedded video audio
      expect(graph.graph, contains('[2:a]')); // Separate audio track
      expect(graph.graph, contains('amix=inputs=2'));
    });

    test('skips audio for embedded video with includeAudio=false', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 300,
          width: 1080,
          height: 1920,
        ),
        sequences: [],
        audioTracks: [],
        embeddedVideos: [
          EmbeddedVideoConfig(
            videoPath: 'test.mp4',
            startFrame: 100,
            durationInFrames: 150,
            trimStartSeconds: 0,
            width: 900,
            height: 500,
            includeAudio: false,
            audioVolume: 1.0,
            audioFadeInFrames: 0,
            audioFadeOutFrames: 0,
            id: 'test_video',
          ),
        ],
      );

      final builder = FFmpegFilterGraphBuilder();
      final graph = builder.build(config);

      // Should NOT have audio output
      expect(graph.audioOutputLabel, isNull);
      expect(graph.graph, isNot(contains('[1:a]')));
    });

    test('skips audio for embedded video with durationInFrames=0', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 300,
          width: 1080,
          height: 1920,
        ),
        sequences: [],
        audioTracks: [],
        embeddedVideos: [
          EmbeddedVideoConfig(
            videoPath: 'test.mp4',
            startFrame: 100,
            durationInFrames: 0, // Zero duration
            trimStartSeconds: 0,
            width: 900,
            height: 500,
            includeAudio: true,
            audioVolume: 1.0,
            audioFadeInFrames: 0,
            audioFadeOutFrames: 0,
            id: 'test_video',
          ),
        ],
      );

      final builder = FFmpegFilterGraphBuilder();
      final graph = builder.build(config);

      // Should NOT have audio output due to zero duration
      expect(graph.audioOutputLabel, isNull);
    });
  });
}
