import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/encoding/ffmpeg_filter_graph_builder.dart';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/domain/audio_config.dart';
import 'package:fluvie/src/domain/embedded_video_config.dart';

void main() {
  group('FFmpegFilterGraphBuilder', () {
    late FFmpegFilterGraphBuilder builder;

    setUp(() {
      builder = FFmpegFilterGraphBuilder();
    });

    RenderConfig createConfig({
      int fps = 30,
      int width = 1920,
      int height = 1080,
      int durationInFrames = 300,
      List<EmbeddedVideoConfig> embeddedVideos = const [],
      List<AudioTrackConfig> audioTracks = const [],
    }) {
      return RenderConfig(
        timeline: TimelineConfig(
          fps: fps,
          width: width,
          height: height,
          durationInFrames: durationInFrames,
        ),
        sequences: const [],
        embeddedVideos: embeddedVideos,
        audioTracks: audioTracks,
      );
    }

    group('basic video filter', () {
      test('builds base video filter with correct fps', () {
        final config = createConfig(fps: 30);
        final graph = builder.build(config);

        expect(graph.graph, contains('fps=30'));
        expect(graph.graph, contains('format=yuv420p'));
        expect(graph.graph, contains('[v_out]'));
      });

      test('builds base video filter with different fps', () {
        final config = createConfig(fps: 60);
        final graph = builder.build(config);

        expect(graph.graph, contains('fps=60'));
      });

      test('video output label is always [v_out]', () {
        final config = createConfig();
        final graph = builder.build(config);

        expect(graph.videoOutputLabel, '[v_out]');
      });
    });

    group('no audio', () {
      test('audio output label is null when no audio sources', () {
        final config = createConfig();
        final graph = builder.build(config);

        expect(graph.audioOutputLabel, isNull);
      });

      test('embedded video count is 0 when none', () {
        final config = createConfig();
        final graph = builder.build(config);

        expect(graph.embeddedVideoCount, 0);
      });
    });

    group('single audio track', () {
      test('builds filter for single audio track', () {
        final config = createConfig(
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.audioOutputLabel, '[a_mix_out]');
        expect(graph.graph, contains('[1:a]'));
      });

      test('applies trim filter when trimStartFrame > 0', () {
        final config = createConfig(
          fps: 30,
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
              trimStartFrame: 30, // 1 second at 30fps
            ),
          ],
        );
        final graph = builder.build(config);

        // Should have atrim with start=1.0
        expect(graph.graph, contains('atrim'));
        expect(graph.graph, contains('start=1.0'));
      });

      test('applies fade in filter', () {
        final config = createConfig(
          fps: 30,
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
              fadeInFrames: 15, // 0.5 second at 30fps
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.graph, contains('afade=t=in'));
        expect(graph.graph, contains('st=0'));
        expect(graph.graph, contains('d=0.5'));
      });

      test('applies fade out filter', () {
        final config = createConfig(
          fps: 30,
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300, // 10 seconds
              fadeOutFrames: 30, // 1 second
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.graph, contains('afade=t=out'));
        // Fade out should start at 9 seconds (10 - 1)
        expect(graph.graph, contains('st=9'));
        expect(graph.graph, contains('d=1.0'));
      });

      test('applies volume filter when not 1.0', () {
        final config = createConfig(
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
              volume: 0.5,
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.graph, contains('volume=0.5'));
      });

      test('does not apply volume filter when 1.0', () {
        final config = createConfig(
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
              volume: 1.0,
            ),
          ],
        );
        final graph = builder.build(config);

        // volume=1.0 should not be present (no-op)
        expect(graph.graph.contains('volume=1.0'), isFalse);
      });

      test('applies delay filter when startFrame > 0', () {
        final config = createConfig(
          fps: 30,
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 60, // 2 seconds at 30fps
              durationInFrames: 300,
            ),
          ],
        );
        final graph = builder.build(config);

        // Should have adelay=2000|2000 (2000ms = 2 seconds)
        expect(graph.graph, contains('adelay=2000|2000'));
      });

      test('applies loop filter when loop is true', () {
        final config = createConfig(
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
              loop: true,
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.graph, contains('aloop=loop=-1:size=0'));
      });
    });

    group('multiple audio tracks', () {
      test('uses amix for multiple tracks', () {
        final config = createConfig(
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music1.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
            ),
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music2.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.graph, contains('amix=inputs=2'));
        expect(graph.graph, contains('duration=longest'));
        expect(graph.graph, contains('[a_mix_out]'));
      });

      test('correct input indices for multiple tracks', () {
        final config = createConfig(
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music1.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
            ),
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music2.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
            ),
          ],
        );
        final graph = builder.build(config);

        // First track uses input [1:a], second uses [2:a]
        expect(graph.graph, contains('[1:a]'));
        expect(graph.graph, contains('[2:a]'));
      });
    });

    group('embedded videos with audio', () {
      test('extracts audio from embedded video', () {
        final config = createConfig(
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video.mp4',
              startFrame: 0,
              durationInFrames: 150,
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              id: 'video_1',
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.embeddedVideoCount, 1);
        expect(graph.audioOutputLabel, '[a_mix_out]');
        // Audio from first embedded video is [1:a]
        expect(graph.graph, contains('[1:a]'));
      });

      test('skips audio when includeAudio is false', () {
        final config = createConfig(
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video.mp4',
              startFrame: 0,
              durationInFrames: 150,
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: false,
              id: 'video_1',
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.embeddedVideoCount, 1);
        expect(graph.audioOutputLabel, isNull);
      });

      test('skips audio when duration is 0', () {
        final config = createConfig(
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video.mp4',
              startFrame: 0,
              durationInFrames: 0, // Invalid duration
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              id: 'video_1',
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.audioOutputLabel, isNull);
      });

      test('applies audio fade in for embedded video', () {
        final config = createConfig(
          fps: 30,
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video.mp4',
              startFrame: 0,
              durationInFrames: 150,
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              audioFadeInFrames: 15,
              id: 'video_1',
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.graph, contains('afade=t=in'));
      });

      test('applies audio fade out for embedded video', () {
        final config = createConfig(
          fps: 30,
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video.mp4',
              startFrame: 0,
              durationInFrames: 150, // 5 seconds at 30fps
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              audioFadeOutFrames: 30, // 1 second
              id: 'video_1',
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.graph, contains('afade=t=out'));
      });

      test('applies volume to embedded video audio', () {
        final config = createConfig(
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video.mp4',
              startFrame: 0,
              durationInFrames: 150,
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              audioVolume: 0.7,
              id: 'video_1',
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.graph, contains('volume=0.7'));
      });

      test('applies delay for embedded video starting later', () {
        final config = createConfig(
          fps: 30,
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video.mp4',
              startFrame: 90, // 3 seconds at 30fps
              durationInFrames: 150,
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              id: 'video_1',
            ),
          ],
        );
        final graph = builder.build(config);

        // Should delay by 3000ms
        expect(graph.graph, contains('adelay=3000|3000'));
      });
    });

    group('mixed audio sources', () {
      test('mixes embedded video audio with separate audio tracks', () {
        final config = createConfig(
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video.mp4',
              startFrame: 0,
              durationInFrames: 150,
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              id: 'video_1',
            ),
          ],
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
            ),
          ],
        );
        final graph = builder.build(config);

        // Should have amix with 2 inputs (embedded + separate)
        expect(graph.graph, contains('amix=inputs=2'));
        // Embedded video audio is [1:a], separate audio is [2:a]
        expect(graph.graph, contains('[1:a]'));
        expect(graph.graph, contains('[2:a]'));
      });

      test('correct input indices with multiple embedded videos', () {
        final config = createConfig(
          embeddedVideos: [
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video1.mp4',
              startFrame: 0,
              durationInFrames: 150,
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              id: 'video_1',
            ),
            const EmbeddedVideoConfig(
              videoPath: '/path/to/video2.mp4',
              startFrame: 0,
              durationInFrames: 150,
              trimStartSeconds: 0,
              width: 800,
              height: 600,
              includeAudio: true,
              id: 'video_2',
            ),
          ],
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
            ),
          ],
        );
        final graph = builder.build(config);

        // Input 0: composition frames
        // Input 1: video1 (audio: [1:a])
        // Input 2: video2 (audio: [2:a])
        // Input 3: separate audio ([3:a])
        expect(graph.graph, contains('[1:a]'));
        expect(graph.graph, contains('[2:a]'));
        expect(graph.graph, contains('[3:a]'));
        expect(graph.graph, contains('amix=inputs=3'));
      });
    });

    group('edge cases', () {
      test('handles empty embedded videos list', () {
        final config = createConfig(embeddedVideos: []);
        final graph = builder.build(config);

        expect(graph.embeddedVideoCount, 0);
      });

      test('handles empty audio tracks list', () {
        final config = createConfig(audioTracks: []);
        final graph = builder.build(config);

        expect(graph.audioOutputLabel, isNull);
      });

      test('handles zero fade duration', () {
        final config = createConfig(
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 300,
              fadeInFrames: 0,
              fadeOutFrames: 0,
            ),
          ],
        );
        final graph = builder.build(config);

        // Should not have fade filters when durations are 0
        expect(graph.graph.contains('afade=t=in:st=0:d=0'), isFalse);
      });

      test('handles very short audio duration', () {
        final config = createConfig(
          fps: 30,
          audioTracks: [
            const AudioTrackConfig(
              source: AudioSourceConfig(
                type: AudioSourceType.file,
                uri: '/path/to/music.mp3',
              ),
              startFrame: 0,
              durationInFrames: 1, // Single frame
            ),
          ],
        );
        final graph = builder.build(config);

        expect(graph.audioOutputLabel, '[a_mix_out]');
      });
    });
  });

  group('FFmpegFilterGraph', () {
    test('creates with required properties', () {
      const graph = FFmpegFilterGraph(
        graph: '[0:v]fps=30,format=yuv420p[v_out]',
        videoOutputLabel: '[v_out]',
      );

      expect(graph.graph, '[0:v]fps=30,format=yuv420p[v_out]');
      expect(graph.videoOutputLabel, '[v_out]');
      expect(graph.audioOutputLabel, isNull);
      expect(graph.embeddedVideoCount, 0);
    });

    test('creates with audio output label', () {
      const graph = FFmpegFilterGraph(
        graph: '[0:v]fps=30[v_out];[1:a]anull[a_mix_out]',
        videoOutputLabel: '[v_out]',
        audioOutputLabel: '[a_mix_out]',
      );

      expect(graph.audioOutputLabel, '[a_mix_out]');
    });

    test('creates with embedded video count', () {
      const graph = FFmpegFilterGraph(
        graph: '[0:v]fps=30[v_out]',
        videoOutputLabel: '[v_out]',
        embeddedVideoCount: 3,
      );

      expect(graph.embeddedVideoCount, 3);
    });
  });
}
