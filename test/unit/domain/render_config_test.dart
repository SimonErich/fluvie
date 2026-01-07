import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/domain/audio_config.dart';
import 'package:fluvie/src/domain/embedded_video_config.dart';
import 'package:fluvie/src/domain/spatial_properties.dart';

void main() {
  group('RenderConfig', () {
    test('creates with required fields', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 90,
          width: 1920,
          height: 1080,
        ),
        sequences: const [],
      );

      expect(config.timeline.fps, 30);
      expect(config.timeline.durationInFrames, 90);
      expect(config.timeline.width, 1920);
      expect(config.timeline.height, 1080);
      expect(config.sequences, isEmpty);
      expect(config.audioTracks, isEmpty);
      expect(config.embeddedVideos, isEmpty);
      expect(config.encoding, isNull);
    });

    test('creates with all optional fields', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 60,
          durationInFrames: 180,
          width: 1080,
          height: 1920,
        ),
        sequences: const [
          SequenceConfig.base(startFrame: 0, durationInFrames: 90),
        ],
        audioTracks: [
          const AudioTrackConfig(
            source: AudioSourceConfig(
              type: AudioSourceType.file,
              uri: 'test.mp3',
            ),
            startFrame: 0,
            durationInFrames: 180,
          ),
        ],
        embeddedVideos: [
          const EmbeddedVideoConfig(
            videoPath: 'test.mp4',
            startFrame: 0,
            durationInFrames: 60,
            trimStartSeconds: 0,
            width: 400,
            height: 300,
            id: 'video1',
          ),
        ],
        encoding: const EncodingConfig(quality: RenderQuality.high),
      );

      expect(config.sequences.length, 1);
      expect(config.audioTracks.length, 1);
      expect(config.embeddedVideos.length, 1);
      expect(config.encoding?.quality, RenderQuality.high);
    });

    test('serializes to JSON correctly', () {
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 90,
          width: 1920,
          height: 1080,
        ),
        sequences: const [],
        encoding: const EncodingConfig(quality: RenderQuality.medium),
      );

      final json = config.toJson();

      expect(json['timeline'], isA<Map>());
      expect(json['timeline']['fps'], 30);
      expect(json['timeline']['durationInFrames'], 90);
      expect(json['sequences'], isA<List>());
      expect(json['encoding'], isA<Map>());
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'timeline': {
          'fps': 30,
          'durationInFrames': 90,
          'width': 1920,
          'height': 1080,
        },
        'sequences': <Map<String, dynamic>>[],
        'audioTracks': <Map<String, dynamic>>[],
        'embeddedVideos': <Map<String, dynamic>>[],
      };

      final config = RenderConfig.fromJson(json);

      expect(config.timeline.fps, 30);
      expect(config.timeline.durationInFrames, 90);
      expect(config.sequences, isEmpty);
    });

    test('roundtrip serialization preserves all fields', () {
      final original = RenderConfig(
        timeline: TimelineConfig(
          fps: 60,
          durationInFrames: 120,
          width: 1080,
          height: 1920,
        ),
        sequences: const [
          SequenceConfig.video(
            startFrame: 10,
            durationInFrames: 50,
            assetPath: 'video.mp4',
            trimStartFrame: 5,
          ),
        ],
        audioTracks: [
          const AudioTrackConfig(
            source: AudioSourceConfig(
              type: AudioSourceType.asset,
              uri: 'audio.mp3',
            ),
            startFrame: 0,
            durationInFrames: 120,
            volume: 0.8,
            fadeInFrames: 10,
          ),
        ],
        encoding: const EncodingConfig(
          quality: RenderQuality.high,
          crfOverride: 18,
          presetOverride: 'slow',
        ),
      );

      final json = original.toJson();
      final restored = RenderConfig.fromJson(json);

      expect(restored.timeline.fps, original.timeline.fps);
      expect(restored.timeline.durationInFrames,
          original.timeline.durationInFrames);
      expect(restored.sequences.length, original.sequences.length);
      expect(restored.sequences.first.type, original.sequences.first.type);
      expect(restored.audioTracks.length, original.audioTracks.length);
      expect(restored.encoding?.quality, original.encoding?.quality);
      expect(restored.encoding?.crfOverride, original.encoding?.crfOverride);
    });
  });

  group('TimelineConfig', () {
    test('creates with required fields', () {
      final config = TimelineConfig(
        fps: 30,
        durationInFrames: 90,
        width: 1920,
        height: 1080,
      );

      expect(config.fps, 30);
      expect(config.durationInFrames, 90);
      expect(config.width, 1920);
      expect(config.height, 1080);
    });

    test('supports common frame rates', () {
      for (final fps in [24, 25, 30, 50, 60]) {
        final config = TimelineConfig(
          fps: fps,
          durationInFrames: 100,
          width: 1920,
          height: 1080,
        );
        expect(config.fps, fps);
      }
    });

    test('supports common resolutions', () {
      final resolutions = [
        (1920, 1080), // 1080p landscape
        (1080, 1920), // 1080p portrait
        (1080, 1080), // Square
        (3840, 2160), // 4K
        (640, 480), // 480p
      ];

      for (final (width, height) in resolutions) {
        final config = TimelineConfig(
          fps: 30,
          durationInFrames: 90,
          width: width,
          height: height,
        );
        expect(config.width, width);
        expect(config.height, height);
      }
    });

    test('serializes to JSON', () {
      final config = TimelineConfig(
        fps: 30,
        durationInFrames: 90,
        width: 1920,
        height: 1080,
      );

      final json = config.toJson();

      expect(json['fps'], 30);
      expect(json['durationInFrames'], 90);
      expect(json['width'], 1920);
      expect(json['height'], 1080);
    });

    test('deserializes from JSON', () {
      final json = {
        'fps': 60,
        'durationInFrames': 180,
        'width': 1080,
        'height': 1920,
      };

      final config = TimelineConfig.fromJson(json);

      expect(config.fps, 60);
      expect(config.durationInFrames, 180);
      expect(config.width, 1080);
      expect(config.height, 1920);
    });
  });

  group('SequenceConfig', () {
    group('base constructor', () {
      test('creates base sequence', () {
        const seq = SequenceConfig.base(
          startFrame: 0,
          durationInFrames: 90,
        );

        expect(seq.type, SequenceType.base);
        expect(seq.startFrame, 0);
        expect(seq.durationInFrames, 90);
        expect(seq.assetPath, isNull);
        expect(seq.text, isNull);
        expect(seq.children, isNull);
      });

      test('base with spatial properties', () {
        const seq = SequenceConfig.base(
          startFrame: 10,
          durationInFrames: 50,
          spatialProps: SpatialProperties(x: 100, y: 200, opacity: 0.5),
        );

        expect(seq.spatialProps, isNotNull);
        expect(seq.spatialProps?.x, 100);
        expect(seq.spatialProps?.y, 200);
        expect(seq.spatialProps?.opacity, 0.5);
      });
    });

    group('video constructor', () {
      test('creates video sequence', () {
        const seq = SequenceConfig.video(
          startFrame: 0,
          durationInFrames: 90,
          assetPath: 'assets/video.mp4',
        );

        expect(seq.type, SequenceType.video);
        expect(seq.isVideo, isTrue);
        expect(seq.isText, isFalse);
        expect(seq.isComposite, isFalse);
        expect(seq.assetPath, 'assets/video.mp4');
      });

      test('video with trim parameters', () {
        const seq = SequenceConfig.video(
          startFrame: 10,
          durationInFrames: 60,
          assetPath: 'video.mp4',
          trimStartFrame: 30,
          trimDurationInFrames: 45,
        );

        expect(seq.trimStartFrame, 30);
        expect(seq.trimDurationInFrames, 45);
      });
    });

    group('text constructor', () {
      test('creates text sequence', () {
        const seq = SequenceConfig.text(
          startFrame: 0,
          durationInFrames: 60,
          text: 'Hello World',
        );

        expect(seq.type, SequenceType.text);
        expect(seq.isText, isTrue);
        expect(seq.isVideo, isFalse);
        expect(seq.isComposite, isFalse);
        expect(seq.text, 'Hello World');
      });
    });

    group('composite constructor', () {
      test('creates composite sequence', () {
        const seq = SequenceConfig.composite(
          startFrame: 0,
          durationInFrames: 120,
          children: [
            SequenceConfig.base(startFrame: 0, durationInFrames: 60),
            SequenceConfig.base(startFrame: 60, durationInFrames: 60),
          ],
        );

        expect(seq.type, SequenceType.composite);
        expect(seq.isComposite, isTrue);
        expect(seq.children, isNotNull);
        expect(seq.children?.length, 2);
      });

      test('composite with nested composites', () {
        const seq = SequenceConfig.composite(
          startFrame: 0,
          durationInFrames: 180,
          children: [
            SequenceConfig.composite(
              startFrame: 0,
              durationInFrames: 90,
              children: [
                SequenceConfig.base(startFrame: 0, durationInFrames: 45),
              ],
            ),
          ],
        );

        expect(seq.children?.first.isComposite, isTrue);
        expect(seq.children?.first.children?.length, 1);
      });
    });

    group('serialization', () {
      test('base sequence roundtrip', () {
        const original = SequenceConfig.base(
          startFrame: 10,
          durationInFrames: 50,
        );

        final json = original.toJson();
        final restored = SequenceConfig.fromJson(json);

        expect(restored.type, original.type);
        expect(restored.startFrame, original.startFrame);
        expect(restored.durationInFrames, original.durationInFrames);
      });

      test('video sequence roundtrip', () {
        const original = SequenceConfig.video(
          startFrame: 0,
          durationInFrames: 90,
          assetPath: 'test.mp4',
          trimStartFrame: 10,
        );

        final json = original.toJson();
        final restored = SequenceConfig.fromJson(json);

        expect(restored.type, SequenceType.video);
        expect(restored.assetPath, 'test.mp4');
        expect(restored.trimStartFrame, 10);
      });
    });
  });

  group('EncodingConfig', () {
    test('default values', () {
      const config = EncodingConfig();

      expect(config.quality, RenderQuality.medium);
      expect(config.crfOverride, isNull);
      expect(config.presetOverride, isNull);
      expect(config.frameFormat, FrameFormat.rawRgba);
    });

    test('quality presets', () {
      const low = EncodingConfig(quality: RenderQuality.low);
      const medium = EncodingConfig(quality: RenderQuality.medium);
      const high = EncodingConfig(quality: RenderQuality.high);
      const lossless = EncodingConfig(quality: RenderQuality.lossless);

      expect(low.quality, RenderQuality.low);
      expect(medium.quality, RenderQuality.medium);
      expect(high.quality, RenderQuality.high);
      expect(lossless.quality, RenderQuality.lossless);
    });

    test('crfOverride takes precedence', () {
      const config = EncodingConfig(
        quality: RenderQuality.low,
        crfOverride: 18,
      );

      expect(config.quality, RenderQuality.low);
      expect(config.crfOverride, 18);
    });

    test('presetOverride takes precedence', () {
      const config = EncodingConfig(
        quality: RenderQuality.low,
        presetOverride: 'veryslow',
      );

      expect(config.presetOverride, 'veryslow');
    });

    test('PNG frame format', () {
      const config = EncodingConfig(frameFormat: FrameFormat.png);

      expect(config.frameFormat, FrameFormat.png);
    });

    test('serialization roundtrip', () {
      const original = EncodingConfig(
        quality: RenderQuality.high,
        crfOverride: 15,
        presetOverride: 'slow',
        frameFormat: FrameFormat.png,
      );

      final json = original.toJson();
      final restored = EncodingConfig.fromJson(json);

      expect(restored.quality, original.quality);
      expect(restored.crfOverride, original.crfOverride);
      expect(restored.presetOverride, original.presetOverride);
      expect(restored.frameFormat, original.frameFormat);
    });
  });

  group('RenderQuality', () {
    test('has all expected values', () {
      expect(RenderQuality.values, contains(RenderQuality.low));
      expect(RenderQuality.values, contains(RenderQuality.medium));
      expect(RenderQuality.values, contains(RenderQuality.high));
      expect(RenderQuality.values, contains(RenderQuality.lossless));
      expect(RenderQuality.values.length, 4);
    });
  });

  group('FrameFormat', () {
    test('has all expected values', () {
      expect(FrameFormat.values, contains(FrameFormat.rawRgba));
      expect(FrameFormat.values, contains(FrameFormat.png));
      expect(FrameFormat.values.length, 2);
    });
  });

  group('SequenceType', () {
    test('has all expected values', () {
      expect(SequenceType.values, contains(SequenceType.base));
      expect(SequenceType.values, contains(SequenceType.video));
      expect(SequenceType.values, contains(SequenceType.text));
      expect(SequenceType.values, contains(SequenceType.composite));
      expect(SequenceType.values.length, 4);
    });
  });
}
