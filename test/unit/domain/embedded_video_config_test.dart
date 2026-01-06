import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/domain/embedded_video_config.dart';

void main() {
  group('EmbeddedVideoConfig', () {
    test('creates with required fields', () {
      const config = EmbeddedVideoConfig(
        videoPath: 'assets/video.mp4',
        startFrame: 0,
        durationInFrames: 90,
        trimStartSeconds: 0,
        width: 400,
        height: 300,
        id: 'video1',
      );

      expect(config.videoPath, 'assets/video.mp4');
      expect(config.startFrame, 0);
      expect(config.durationInFrames, 90);
      expect(config.trimStartSeconds, 0);
      expect(config.width, 400);
      expect(config.height, 300);
      expect(config.id, 'video1');
    });

    test('default values', () {
      const config = EmbeddedVideoConfig(
        videoPath: 'video.mp4',
        startFrame: 0,
        durationInFrames: 60,
        trimStartSeconds: 0,
        width: 640,
        height: 480,
        id: 'test',
      );

      expect(config.positionX, 0);
      expect(config.positionY, 0);
      expect(config.includeAudio, isTrue);
      expect(config.audioVolume, 1.0);
      expect(config.audioFadeInFrames, 0);
      expect(config.audioFadeOutFrames, 0);
    });

    test('creates with all optional fields', () {
      const config = EmbeddedVideoConfig(
        videoPath: 'video.mp4',
        startFrame: 30,
        durationInFrames: 120,
        trimStartSeconds: 5.5,
        width: 800,
        height: 600,
        positionX: 100,
        positionY: 200,
        includeAudio: false,
        audioVolume: 0.5,
        audioFadeInFrames: 10,
        audioFadeOutFrames: 15,
        id: 'embed1',
      );

      expect(config.positionX, 100);
      expect(config.positionY, 200);
      expect(config.includeAudio, isFalse);
      expect(config.audioVolume, 0.5);
      expect(config.audioFadeInFrames, 10);
      expect(config.audioFadeOutFrames, 15);
    });

    group('computed properties', () {
      test('endFrame calculation', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 30,
          durationInFrames: 60,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          id: 'test',
        );

        expect(config.endFrame, 90); // 30 + 60
      });

      test('startTimeSeconds at 30fps', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 60,
          durationInFrames: 90,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          id: 'test',
        );

        expect(config.startTimeSeconds(30), 2.0); // 60/30 = 2
      });

      test('endTimeSeconds at 30fps', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 30,
          durationInFrames: 60,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          id: 'test',
        );

        expect(config.endTimeSeconds(30), 3.0); // (30+60)/30 = 3
      });

      test('durationSeconds at 30fps', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 0,
          durationInFrames: 90,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          id: 'test',
        );

        expect(config.durationSeconds(30), 3.0); // 90/30 = 3
      });

      test('startTimeSeconds at 60fps', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 120,
          durationInFrames: 60,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          id: 'test',
        );

        expect(config.startTimeSeconds(60), 2.0); // 120/60 = 2
      });
    });

    group('copyWith', () {
      test('copies all fields correctly', () {
        const original = EmbeddedVideoConfig(
          videoPath: 'original.mp4',
          startFrame: 0,
          durationInFrames: 60,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          positionX: 10,
          positionY: 20,
          includeAudio: true,
          audioVolume: 1.0,
          audioFadeInFrames: 5,
          audioFadeOutFrames: 10,
          id: 'orig',
        );

        final copied = original.copyWith(
          videoPath: 'new.mp4',
          startFrame: 30,
          width: 800,
          includeAudio: false,
        );

        expect(copied.videoPath, 'new.mp4');
        expect(copied.startFrame, 30);
        expect(copied.durationInFrames, 60); // Unchanged
        expect(copied.trimStartSeconds, 0); // Unchanged
        expect(copied.width, 800);
        expect(copied.height, 300); // Unchanged
        expect(copied.positionX, 10); // Unchanged
        expect(copied.positionY, 20); // Unchanged
        expect(copied.includeAudio, isFalse);
        expect(copied.audioVolume, 1.0); // Unchanged
        expect(copied.audioFadeInFrames, 5); // Unchanged
        expect(copied.audioFadeOutFrames, 10); // Unchanged
        expect(copied.id, 'orig'); // Unchanged
      });

      test('can change id', () {
        const original = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 0,
          durationInFrames: 60,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          id: 'original_id',
        );

        final copied = original.copyWith(id: 'new_id');

        expect(copied.id, 'new_id');
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 30,
          durationInFrames: 60,
          trimStartSeconds: 2.5,
          width: 400,
          height: 300,
          positionX: 100,
          positionY: 200,
          includeAudio: true,
          id: 'test',
        );

        final str = config.toString();

        expect(str, contains('video.mp4'));
        expect(str, contains('startFrame: 30'));
        expect(str, contains('duration: 60'));
        expect(str, contains('trim: 2.5s'));
        expect(str, contains('size: 400x300'));
        expect(str, contains('pos: (100.0, 200.0)'));
        expect(str, contains('audio: true'));
      });
    });

    group('serialization', () {
      test('roundtrip with all fields', () {
        const original = EmbeddedVideoConfig(
          videoPath: 'assets/test.mp4',
          startFrame: 60,
          durationInFrames: 120,
          trimStartSeconds: 3.5,
          width: 1280,
          height: 720,
          positionX: 320,
          positionY: 180,
          includeAudio: true,
          audioVolume: 0.8,
          audioFadeInFrames: 15,
          audioFadeOutFrames: 20,
          id: 'embed_video_1',
        );

        final json = original.toJson();
        final restored = EmbeddedVideoConfig.fromJson(json);

        expect(restored.videoPath, original.videoPath);
        expect(restored.startFrame, original.startFrame);
        expect(restored.durationInFrames, original.durationInFrames);
        expect(restored.trimStartSeconds, original.trimStartSeconds);
        expect(restored.width, original.width);
        expect(restored.height, original.height);
        expect(restored.positionX, original.positionX);
        expect(restored.positionY, original.positionY);
        expect(restored.includeAudio, original.includeAudio);
        expect(restored.audioVolume, original.audioVolume);
        expect(restored.audioFadeInFrames, original.audioFadeInFrames);
        expect(restored.audioFadeOutFrames, original.audioFadeOutFrames);
        expect(restored.id, original.id);
      });

      test('roundtrip with default values', () {
        const original = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 0,
          durationInFrames: 90,
          trimStartSeconds: 0,
          width: 640,
          height: 480,
          id: 'test',
        );

        final json = original.toJson();
        final restored = EmbeddedVideoConfig.fromJson(json);

        expect(restored.positionX, 0);
        expect(restored.positionY, 0);
        expect(restored.includeAudio, true);
        expect(restored.audioVolume, 1.0);
      });
    });

    group('edge cases', () {
      test('zero duration', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 0,
          durationInFrames: 0,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          id: 'test',
        );

        expect(config.endFrame, 0);
        expect(config.durationSeconds(30), 0.0);
      });

      test('large frame numbers', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 108000, // 1 hour at 30fps
          durationInFrames: 54000, // 30 minutes at 30fps
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          id: 'test',
        );

        expect(config.endFrame, 162000);
        expect(config.startTimeSeconds(30), 3600.0); // 1 hour
        expect(config.durationSeconds(30), 1800.0); // 30 minutes
      });

      test('fractional position values', () {
        const config = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 0,
          durationInFrames: 60,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          positionX: 100.5,
          positionY: 200.75,
          id: 'test',
        );

        expect(config.positionX, 100.5);
        expect(config.positionY, 200.75);
      });

      test('audio volume at boundaries', () {
        const silent = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 0,
          durationInFrames: 60,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          audioVolume: 0.0,
          id: 'test',
        );

        const full = EmbeddedVideoConfig(
          videoPath: 'video.mp4',
          startFrame: 0,
          durationInFrames: 60,
          trimStartSeconds: 0,
          width: 400,
          height: 300,
          audioVolume: 1.0,
          id: 'test',
        );

        expect(silent.audioVolume, 0.0);
        expect(full.audioVolume, 1.0);
      });
    });
  });
}
