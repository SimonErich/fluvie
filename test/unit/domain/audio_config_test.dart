import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/domain/audio_config.dart';

void main() {
  group('AudioTrackConfig', () {
    test('creates with required fields', () {
      final config = AudioTrackConfig(
        source: const AudioSourceConfig(
          type: AudioSourceType.file,
          uri: 'audio.mp3',
        ),
        startFrame: 0,
        durationInFrames: 90,
      );

      expect(config.startFrame, 0);
      expect(config.durationInFrames, 90);
      expect(config.source.type, AudioSourceType.file);
      expect(config.source.uri, 'audio.mp3');
    });

    test('default values', () {
      final config = AudioTrackConfig(
        source: const AudioSourceConfig(
          type: AudioSourceType.file,
          uri: 'test.mp3',
        ),
        startFrame: 0,
        durationInFrames: 100,
      );

      expect(config.trimStartFrame, 0);
      expect(config.trimEndFrame, isNull);
      expect(config.volume, 1.0);
      expect(config.fadeInFrames, 0);
      expect(config.fadeOutFrames, 0);
      expect(config.loop, isFalse);
      expect(config.sync, isNull);
    });

    test('creates with all optional fields', () {
      final config = AudioTrackConfig(
        source: const AudioSourceConfig(
          type: AudioSourceType.asset,
          uri: 'assets/music.mp3',
        ),
        startFrame: 30,
        durationInFrames: 120,
        trimStartFrame: 15,
        trimEndFrame: 180,
        volume: 0.8,
        fadeInFrames: 10,
        fadeOutFrames: 20,
        loop: true,
        sync: const AudioSyncConfig(
          syncStartWithAnchor: 'anchor1',
          startOffset: 5,
        ),
      );

      expect(config.trimStartFrame, 15);
      expect(config.trimEndFrame, 180);
      expect(config.volume, 0.8);
      expect(config.fadeInFrames, 10);
      expect(config.fadeOutFrames, 20);
      expect(config.loop, isTrue);
      expect(config.sync, isNotNull);
    });

    group('trimStartFrameToMs', () {
      test('converts frames to milliseconds at 30fps', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 0,
          durationInFrames: 90,
          trimStartFrame: 30, // 1 second at 30fps
        );

        expect(config.trimStartFrameToMs(30), 1000);
      });

      test('converts frames to milliseconds at 60fps', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 0,
          durationInFrames: 90,
          trimStartFrame: 60, // 1 second at 60fps
        );

        expect(config.trimStartFrameToMs(60), 1000);
      });

      test('handles zero frames', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 0,
          durationInFrames: 90,
          trimStartFrame: 0,
        );

        expect(config.trimStartFrameToMs(30), 0);
      });
    });

    group('trimEndFrameToMs', () {
      test('converts end frame to milliseconds', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 0,
          durationInFrames: 90,
          trimEndFrame: 90, // 3 seconds at 30fps
        );

        expect(config.trimEndFrameToMs(30), 3000);
      });

      test('returns null when trimEndFrame is null', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 0,
          durationInFrames: 90,
        );

        expect(config.trimEndFrameToMs(30), isNull);
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        final original = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'original.mp3',
          ),
          startFrame: 0,
          durationInFrames: 90,
          volume: 1.0,
        );

        final copied = original.copyWith(
          startFrame: 30,
          volume: 0.5,
        );

        expect(copied.source.uri, 'original.mp3'); // Unchanged
        expect(copied.startFrame, 30); // Changed
        expect(copied.durationInFrames, 90); // Unchanged
        expect(copied.volume, 0.5); // Changed
      });

      test('can clear sync config', () {
        final original = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 0,
          durationInFrames: 90,
          sync: const AudioSyncConfig(syncStartWithAnchor: 'anchor'),
        );

        expect(original.sync, isNotNull);

        final copied = original.copyWith(sync: null);

        expect(copied.sync, isNull);
      });
    });

    group('resolveSync', () {
      test('returns unchanged when no sync config', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 10,
          durationInFrames: 50,
        );

        final resolved = config.resolveSync({});

        expect(resolved.startFrame, 10);
        expect(resolved.durationInFrames, 50);
      });

      test('resolves start frame from anchor', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 0,
          durationInFrames: 50,
          sync: const AudioSyncConfig(
            syncStartWithAnchor: 'intro',
            startOffset: 5,
          ),
        );

        final resolved = config.resolveSync({
          'intro': (startFrame: 30, endFrame: 80),
        });

        expect(resolved.startFrame, 35); // 30 + 5
        expect(resolved.sync, isNull); // Cleared after resolution
      });

      test('resolves duration from end anchor', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 10,
          durationInFrames: 50,
          sync: const AudioSyncConfig(
            syncStartWithAnchor: 'scene',
            syncEndWithAnchor: 'scene',
            startOffset: 0,
            endOffset: -5,
          ),
        );

        final resolved = config.resolveSync({
          'scene': (startFrame: 20, endFrame: 100),
        });

        expect(resolved.startFrame, 20);
        expect(resolved.durationInFrames, 75); // (100-5) - 20 = 75
      });

      test('sets loop when behavior is loopToMatch', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 0,
          durationInFrames: 30,
          loop: false,
          sync: const AudioSyncConfig(
            syncStartWithAnchor: 'long_scene',
            syncEndWithAnchor: 'long_scene',
            behavior: SyncBehavior.loopToMatch,
          ),
        );

        final resolved = config.resolveSync({
          'long_scene': (startFrame: 0, endFrame: 300),
        });

        expect(resolved.loop, isTrue);
      });

      test('returns unchanged when anchor not found', () {
        final config = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.file,
            uri: 'test.mp3',
          ),
          startFrame: 10,
          durationInFrames: 50,
          sync: const AudioSyncConfig(
            syncStartWithAnchor: 'missing',
          ),
        );

        final resolved = config.resolveSync({
          'other': (startFrame: 0, endFrame: 100),
        });

        expect(resolved.startFrame, 10); // Unchanged
      });
    });

    group('serialization', () {
      test('roundtrip with all fields', () {
        final original = AudioTrackConfig(
          source: const AudioSourceConfig(
            type: AudioSourceType.url,
            uri: 'https://example.com/audio.mp3',
          ),
          startFrame: 30,
          durationInFrames: 120,
          trimStartFrame: 10,
          trimEndFrame: 150,
          volume: 0.7,
          fadeInFrames: 15,
          fadeOutFrames: 20,
          loop: true,
          sync: const AudioSyncConfig(
            syncStartWithAnchor: 'anchor',
            startOffset: 5,
          ),
        );

        final json = original.toJson();
        final restored = AudioTrackConfig.fromJson(json);

        expect(restored.source.type, original.source.type);
        expect(restored.source.uri, original.source.uri);
        expect(restored.startFrame, original.startFrame);
        expect(restored.durationInFrames, original.durationInFrames);
        expect(restored.trimStartFrame, original.trimStartFrame);
        expect(restored.trimEndFrame, original.trimEndFrame);
        expect(restored.volume, original.volume);
        expect(restored.fadeInFrames, original.fadeInFrames);
        expect(restored.fadeOutFrames, original.fadeOutFrames);
        expect(restored.loop, original.loop);
        expect(restored.sync?.syncStartWithAnchor, 'anchor');
      });
    });
  });

  group('AudioSourceConfig', () {
    test('creates file source', () {
      const source = AudioSourceConfig(
        type: AudioSourceType.file,
        uri: '/path/to/audio.mp3',
      );

      expect(source.type, AudioSourceType.file);
      expect(source.uri, '/path/to/audio.mp3');
    });

    test('creates asset source', () {
      const source = AudioSourceConfig(
        type: AudioSourceType.asset,
        uri: 'assets/audio/music.mp3',
      );

      expect(source.type, AudioSourceType.asset);
      expect(source.uri, 'assets/audio/music.mp3');
    });

    test('creates url source', () {
      const source = AudioSourceConfig(
        type: AudioSourceType.url,
        uri: 'https://example.com/stream.mp3',
      );

      expect(source.type, AudioSourceType.url);
      expect(source.uri, 'https://example.com/stream.mp3');
    });

    test('serialization roundtrip', () {
      const original = AudioSourceConfig(
        type: AudioSourceType.asset,
        uri: 'audio.mp3',
      );

      final json = original.toJson();
      final restored = AudioSourceConfig.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.uri, original.uri);
    });
  });

  group('AudioSyncConfig', () {
    test('default values', () {
      const config = AudioSyncConfig();

      expect(config.syncStartWithAnchor, isNull);
      expect(config.syncEndWithAnchor, isNull);
      expect(config.startOffset, 0);
      expect(config.endOffset, 0);
      expect(config.behavior, SyncBehavior.stopWhenEnds);
    });

    test('hasSyncConfig returns true when syncStartWithAnchor is set', () {
      const config = AudioSyncConfig(syncStartWithAnchor: 'anchor');

      expect(config.hasSyncConfig, isTrue);
    });

    test('hasSyncConfig returns true when syncEndWithAnchor is set', () {
      const config = AudioSyncConfig(syncEndWithAnchor: 'anchor');

      expect(config.hasSyncConfig, isTrue);
    });

    test('hasSyncConfig returns true when both are set', () {
      const config = AudioSyncConfig(
        syncStartWithAnchor: 'start',
        syncEndWithAnchor: 'end',
      );

      expect(config.hasSyncConfig, isTrue);
    });

    test('hasSyncConfig returns false when neither is set', () {
      const config = AudioSyncConfig(
        startOffset: 10,
        endOffset: -5,
      );

      expect(config.hasSyncConfig, isFalse);
    });

    test('serialization roundtrip', () {
      const original = AudioSyncConfig(
        syncStartWithAnchor: 'scene_start',
        syncEndWithAnchor: 'scene_end',
        startOffset: 5,
        endOffset: -10,
        behavior: SyncBehavior.loopToMatch,
      );

      final json = original.toJson();
      final restored = AudioSyncConfig.fromJson(json);

      expect(restored.syncStartWithAnchor, original.syncStartWithAnchor);
      expect(restored.syncEndWithAnchor, original.syncEndWithAnchor);
      expect(restored.startOffset, original.startOffset);
      expect(restored.endOffset, original.endOffset);
      expect(restored.behavior, original.behavior);
    });
  });

  group('SyncBehavior', () {
    test('has expected values', () {
      expect(SyncBehavior.values, contains(SyncBehavior.stopWhenEnds));
      expect(SyncBehavior.values, contains(SyncBehavior.loopToMatch));
      expect(SyncBehavior.values.length, 2);
    });
  });

  group('AudioSourceType', () {
    test('has expected values', () {
      expect(AudioSourceType.values, contains(AudioSourceType.asset));
      expect(AudioSourceType.values, contains(AudioSourceType.file));
      expect(AudioSourceType.values, contains(AudioSourceType.url));
      expect(AudioSourceType.values.length, 3);
    });
  });

  group('Helper functions', () {
    group('framesToMs', () {
      test('converts 30 frames at 30fps to 1000ms', () {
        expect(framesToMs(30, 30), 1000);
      });

      test('converts 60 frames at 60fps to 1000ms', () {
        expect(framesToMs(60, 60), 1000);
      });

      test('converts 0 frames to 0ms', () {
        expect(framesToMs(0, 30), 0);
      });

      test('handles fractional results', () {
        expect(framesToMs(1, 30), 33); // ~33.33ms rounded
      });
    });

    group('msToFrames', () {
      test('converts 1000ms at 30fps to 30 frames', () {
        expect(msToFrames(1000, 30), 30);
      });

      test('converts 1000ms at 60fps to 60 frames', () {
        expect(msToFrames(1000, 60), 60);
      });

      test('converts 0ms to 0 frames', () {
        expect(msToFrames(0, 30), 0);
      });

      test('handles fractional results', () {
        expect(msToFrames(33, 30), 1); // ~0.99 frames rounded
      });
    });

    test('framesToMs and msToFrames are inverse operations', () {
      const frames = 45;
      const fps = 30;

      final ms = framesToMs(frames, fps);
      final backToFrames = msToFrames(ms, fps);

      expect(backToFrames, frames);
    });
  });
}
