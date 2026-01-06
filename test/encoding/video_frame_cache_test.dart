import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/encoding/video_frame_cache.dart';
import 'package:fluvie/src/encoding/frame_extraction_service.dart';

/// Mock frame extraction service for testing
class MockFrameExtractionService implements FrameExtractionService {
  int extractionCount = 0;
  final Map<int, ExtractedFrame> _frames = {};

  void addFrame(int frameNumber, ExtractedFrame frame) {
    _frames[frameNumber] = frame;
  }

  @override
  String? get ffmpegPath => null;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ExtractedFrame> extractFrame({
    required String videoPath,
    required Duration timestamp,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    extractionCount++;
    final frameNumber = (timestamp.inMicroseconds * 30 / 1000000).round();
    return _frames[frameNumber] ?? _createFrame(frameNumber, width, height);
  }

  @override
  Future<ExtractedFrame> extractFrameByNumber({
    required String videoPath,
    required int frameNumber,
    required double sourceFps,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    extractionCount++;
    await Future.delayed(const Duration(milliseconds: 5));
    return _frames[frameNumber] ?? _createFrame(frameNumber, width, height);
  }

  @override
  Future<List<ExtractedFrame>> extractFrameRange({
    required String videoPath,
    required int startFrame,
    required int endFrame,
    required double sourceFps,
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) async {
    extractionCount++;
    final frames = <ExtractedFrame>[];
    for (int i = startFrame; i <= endFrame; i++) {
      frames.add(_frames[i] ?? _createFrame(i, width, height));
    }
    return frames;
  }

  @override
  Stream<ExtractedFrame> extractFrameStream({
    required String videoPath,
    required int startFrame,
    required double sourceFps,
    required int width,
    required int height,
    int frameCount = 30,
    BoxFit fit = BoxFit.cover,
  }) async* {
    extractionCount++;
    for (int i = 0; i < frameCount; i++) {
      final frameNumber = startFrame + i;
      yield _frames[frameNumber] ?? _createFrame(frameNumber, width, height);
    }
  }

  ExtractedFrame _createFrame(int frameNumber, int width, int height) {
    return ExtractedFrame(
      frameNumber: frameNumber,
      rgba: Uint8List(width * height * 4),
      width: width,
      height: height,
    );
  }
}

void main() {
  group('VideoFrameCache', () {
    group('construction', () {
      test('creates with default values', () {
        final cache = VideoFrameCache();

        expect(cache.maxFrames, 90);
        expect(cache.maxMemoryBytes, 500 * 1024 * 1024);
        expect(cache.frameCount, 0);
        expect(cache.memoryUsage, 0);
      });

      test('creates with custom values', () {
        final cache = VideoFrameCache(
          maxFrames: 30,
          maxMemoryBytes: 100 * 1024 * 1024,
        );

        expect(cache.maxFrames, 30);
        expect(cache.maxMemoryBytes, 100 * 1024 * 1024);
      });
    });

    group('get', () {
      test('returns null for uncached frame', () {
        final cache = VideoFrameCache();

        final frame = cache.get('video.mp4', 0);
        expect(frame, isNull);
      });

      test('returns cached frame', () {
        final cache = VideoFrameCache();
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(100 * 100 * 4),
          width: 100,
          height: 100,
        );

        cache.put('video.mp4', 0, frame);
        final retrieved = cache.get('video.mp4', 0);

        expect(retrieved, isNotNull);
        expect(retrieved!.frameNumber, 0);
      });

      test('moves accessed frame to end (LRU)', () {
        final cache = VideoFrameCache(maxFrames: 3);

        // Add three frames
        for (int i = 0; i < 3; i++) {
          cache.put(
            'video.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(100 * 100 * 4),
              width: 100,
              height: 100,
            ),
          );
        }

        // Access frame 0 to make it most recently used
        cache.get('video.mp4', 0);

        // Add a new frame - should evict frame 1 (oldest not accessed)
        cache.put(
          'video.mp4',
          3,
          ExtractedFrame(
            frameNumber: 3,
            rgba: Uint8List(100 * 100 * 4),
            width: 100,
            height: 100,
          ),
        );

        // Frame 0 should still be present (was accessed)
        expect(cache.has('video.mp4', 0), isTrue);
        // Frame 3 should be present (just added)
        expect(cache.has('video.mp4', 3), isTrue);
      });
    });

    group('put', () {
      test('stores frame in cache', () {
        final cache = VideoFrameCache();
        final frame = ExtractedFrame(
          frameNumber: 5,
          rgba: Uint8List(100 * 100 * 4),
          width: 100,
          height: 100,
        );

        cache.put('video.mp4', 5, frame);

        expect(cache.has('video.mp4', 5), isTrue);
        expect(cache.frameCount, 1);
      });

      test('updates memory usage', () {
        final cache = VideoFrameCache();
        final frame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(100 * 100 * 4), // 40000 bytes
          width: 100,
          height: 100,
        );

        cache.put('video.mp4', 0, frame);

        expect(cache.memoryUsage, 40000);
      });

      test('replaces existing frame', () {
        final cache = VideoFrameCache();
        final frame1 = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(100 * 100 * 4),
          width: 100,
          height: 100,
        );
        final frame2 = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(200 * 200 * 4),
          width: 200,
          height: 200,
        );

        cache.put('video.mp4', 0, frame1);
        cache.put('video.mp4', 0, frame2);

        expect(cache.frameCount, 1);
        expect(cache.memoryUsage, 200 * 200 * 4);
      });
    });

    group('has', () {
      test('returns false for uncached frame', () {
        final cache = VideoFrameCache();

        expect(cache.has('video.mp4', 0), isFalse);
      });

      test('returns true for cached frame', () {
        final cache = VideoFrameCache();
        cache.put(
          'video.mp4',
          0,
          ExtractedFrame(
            frameNumber: 0,
            rgba: Uint8List(100 * 100 * 4),
            width: 100,
            height: 100,
          ),
        );

        expect(cache.has('video.mp4', 0), isTrue);
      });
    });

    group('eviction by frame count', () {
      test('evicts oldest frame when maxFrames exceeded', () {
        final cache = VideoFrameCache(maxFrames: 2);

        // Add two frames
        cache.put(
          'video.mp4',
          0,
          ExtractedFrame(
            frameNumber: 0,
            rgba: Uint8List(10),
            width: 1,
            height: 1,
          ),
        );
        cache.put(
          'video.mp4',
          1,
          ExtractedFrame(
            frameNumber: 1,
            rgba: Uint8List(10),
            width: 1,
            height: 1,
          ),
        );

        // Add third frame - should evict frame 0
        cache.put(
          'video.mp4',
          2,
          ExtractedFrame(
            frameNumber: 2,
            rgba: Uint8List(10),
            width: 1,
            height: 1,
          ),
        );

        expect(cache.frameCount, 2);
        expect(cache.has('video.mp4', 0), isFalse);
        expect(cache.has('video.mp4', 1), isTrue);
        expect(cache.has('video.mp4', 2), isTrue);
      });
    });

    group('eviction by memory', () {
      test('evicts frames when maxMemoryBytes exceeded', () {
        final cache = VideoFrameCache(
          maxFrames: 100,
          maxMemoryBytes: 50, // Very small limit
        );

        // Add a frame with 40 bytes
        cache.put(
          'video.mp4',
          0,
          ExtractedFrame(
            frameNumber: 0,
            rgba: Uint8List(40),
            width: 10,
            height: 1,
          ),
        );

        expect(cache.frameCount, 1);

        // Add another frame with 40 bytes - should evict first
        cache.put(
          'video.mp4',
          1,
          ExtractedFrame(
            frameNumber: 1,
            rgba: Uint8List(40),
            width: 10,
            height: 1,
          ),
        );

        expect(cache.frameCount, 1);
        expect(cache.has('video.mp4', 0), isFalse);
        expect(cache.has('video.mp4', 1), isTrue);
      });
    });

    group('getOrExtract', () {
      test('returns cached frame without extraction', () async {
        final cache = VideoFrameCache();
        final service = MockFrameExtractionService();

        // Pre-populate cache
        final existingFrame = ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(100 * 100 * 4),
          width: 100,
          height: 100,
        );
        cache.put('video.mp4', 0, existingFrame);

        final frame = await cache.getOrExtract(
          service,
          videoPath: 'video.mp4',
          frameNumber: 0,
          sourceFps: 30.0,
          width: 100,
          height: 100,
        );

        expect(frame.frameNumber, 0);
        expect(service.extractionCount, 0); // No extraction needed
      });

      test('extracts and caches frame when not cached', () async {
        final cache = VideoFrameCache();
        final service = MockFrameExtractionService();

        final frame = await cache.getOrExtract(
          service,
          videoPath: 'video.mp4',
          frameNumber: 5,
          sourceFps: 30.0,
          width: 100,
          height: 100,
        );

        expect(frame.frameNumber, 5);
        expect(service.extractionCount, 1);
        expect(cache.has('video.mp4', 5), isTrue);
      });

      test('deduplicates concurrent extractions', () async {
        final cache = VideoFrameCache();
        final service = MockFrameExtractionService();

        // Start multiple concurrent extractions for the same frame
        final futures = List.generate(
          5,
          (_) => cache.getOrExtract(
            service,
            videoPath: 'video.mp4',
            frameNumber: 10,
            sourceFps: 30.0,
            width: 100,
            height: 100,
          ),
        );

        final results = await Future.wait(futures);

        // All should return the same frame
        for (final frame in results) {
          expect(frame.frameNumber, 10);
        }

        // Only one extraction should have occurred
        expect(service.extractionCount, 1);
      });
    });

    group('preloadAhead', () {
      test('preloads uncached frames', () async {
        final cache = VideoFrameCache();
        final service = MockFrameExtractionService();

        await cache.preloadAhead(
          service,
          videoPath: 'video.mp4',
          currentFrame: 0,
          aheadCount: 5,
          sourceFps: 30.0,
          width: 100,
          height: 100,
        );

        // All frames should be cached
        for (int i = 0; i < 5; i++) {
          expect(cache.has('video.mp4', i), isTrue);
        }
      });

      test('skips already cached frames', () async {
        final cache = VideoFrameCache();
        final service = MockFrameExtractionService();

        // Pre-populate frame 2
        cache.put(
          'video.mp4',
          2,
          ExtractedFrame(
            frameNumber: 2,
            rgba: Uint8List(100 * 100 * 4),
            width: 100,
            height: 100,
          ),
        );

        await cache.preloadAhead(
          service,
          videoPath: 'video.mp4',
          currentFrame: 0,
          aheadCount: 5,
          sourceFps: 30.0,
          width: 100,
          height: 100,
        );

        // Should extract 4 frames, not 5 (frame 2 was cached)
        expect(service.extractionCount, 4);
      });

      test('respects totalFrames limit', () async {
        final cache = VideoFrameCache();
        final service = MockFrameExtractionService();

        await cache.preloadAhead(
          service,
          videoPath: 'video.mp4',
          currentFrame: 8,
          aheadCount: 10,
          sourceFps: 30.0,
          width: 100,
          height: 100,
          totalFrames: 10, // Only frames 0-9 exist
        );

        // Should only cache frames 8 and 9
        expect(cache.has('video.mp4', 8), isTrue);
        expect(cache.has('video.mp4', 9), isTrue);
        expect(cache.has('video.mp4', 10), isFalse);
      });
    });

    group('preloadRange', () {
      test('preloads frame range', () async {
        final cache = VideoFrameCache();
        final service = MockFrameExtractionService();

        await cache.preloadRange(
          service,
          videoPath: 'video.mp4',
          startFrame: 0,
          endFrame: 4,
          sourceFps: 30.0,
          width: 100,
          height: 100,
        );

        for (int i = 0; i <= 4; i++) {
          expect(cache.has('video.mp4', i), isTrue);
        }
      });

      test('skips already cached frames in range', () async {
        final cache = VideoFrameCache();
        final service = MockFrameExtractionService();

        // Pre-populate frames 1 and 2
        for (int i = 1; i <= 2; i++) {
          cache.put(
            'video.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(100 * 100 * 4),
              width: 100,
              height: 100,
            ),
          );
        }

        await cache.preloadRange(
          service,
          videoPath: 'video.mp4',
          startFrame: 0,
          endFrame: 4,
          sourceFps: 30.0,
          width: 100,
          height: 100,
        );

        // Should extract remaining frames
        expect(cache.has('video.mp4', 0), isTrue);
        expect(cache.has('video.mp4', 3), isTrue);
        expect(cache.has('video.mp4', 4), isTrue);
      });
    });

    group('evictOutsideWindow', () {
      test('evicts frames outside window', () {
        final cache = VideoFrameCache();

        // Add frames 0-9
        for (int i = 0; i < 10; i++) {
          cache.put(
            'video.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(10),
              width: 1,
              height: 1,
            ),
          );
        }

        expect(cache.frameCount, 10);

        // Keep only frames around frame 5 with window size 4
        cache.evictOutsideWindow(
          videoPath: 'video.mp4',
          centerFrame: 5,
          windowSize: 4,
        );

        // Frames 3-7 should remain (5 ± 2)
        expect(cache.has('video.mp4', 0), isFalse);
        expect(cache.has('video.mp4', 1), isFalse);
        expect(cache.has('video.mp4', 2), isFalse);
        expect(cache.has('video.mp4', 3), isTrue);
        expect(cache.has('video.mp4', 4), isTrue);
        expect(cache.has('video.mp4', 5), isTrue);
        expect(cache.has('video.mp4', 6), isTrue);
        expect(cache.has('video.mp4', 7), isTrue);
        expect(cache.has('video.mp4', 8), isFalse);
        expect(cache.has('video.mp4', 9), isFalse);
      });

      test('only affects specified video', () {
        final cache = VideoFrameCache();

        // Add frames for two videos
        for (int i = 0; i < 5; i++) {
          cache.put(
            'video1.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(10),
              width: 1,
              height: 1,
            ),
          );
          cache.put(
            'video2.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(10),
              width: 1,
              height: 1,
            ),
          );
        }

        cache.evictOutsideWindow(
          videoPath: 'video1.mp4',
          centerFrame: 2,
          windowSize: 2,
        );

        // video1 frames outside window should be evicted
        expect(cache.has('video1.mp4', 0), isFalse);
        expect(cache.has('video1.mp4', 4), isFalse);

        // video2 frames should be unaffected
        for (int i = 0; i < 5; i++) {
          expect(cache.has('video2.mp4', i), isTrue);
        }
      });
    });

    group('clearVideo', () {
      test('clears all frames for specific video', () {
        final cache = VideoFrameCache();

        for (int i = 0; i < 5; i++) {
          cache.put(
            'video1.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(10),
              width: 1,
              height: 1,
            ),
          );
          cache.put(
            'video2.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(10),
              width: 1,
              height: 1,
            ),
          );
        }

        cache.clearVideo('video1.mp4');

        // video1 frames should be cleared
        for (int i = 0; i < 5; i++) {
          expect(cache.has('video1.mp4', i), isFalse);
        }

        // video2 frames should remain
        for (int i = 0; i < 5; i++) {
          expect(cache.has('video2.mp4', i), isTrue);
        }
      });

      test('updates memory usage after clear', () {
        final cache = VideoFrameCache();

        for (int i = 0; i < 5; i++) {
          cache.put(
            'video.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(100),
              width: 10,
              height: 1,
            ),
          );
        }

        expect(cache.memoryUsage, 500);

        cache.clearVideo('video.mp4');

        expect(cache.memoryUsage, 0);
      });
    });

    group('clearAll', () {
      test('clears all frames', () {
        final cache = VideoFrameCache();

        for (int i = 0; i < 5; i++) {
          cache.put(
            'video1.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(10),
              width: 1,
              height: 1,
            ),
          );
          cache.put(
            'video2.mp4',
            i,
            ExtractedFrame(
              frameNumber: i,
              rgba: Uint8List(10),
              width: 1,
              height: 1,
            ),
          );
        }

        cache.clearAll();

        expect(cache.frameCount, 0);
        expect(cache.memoryUsage, 0);
      });
    });

    group('memoryUsageRatio', () {
      test('returns correct ratio', () {
        final cache = VideoFrameCache(
          maxFrames: 100,
          maxMemoryBytes: 1000,
        );

        cache.put(
          'video.mp4',
          0,
          ExtractedFrame(
            frameNumber: 0,
            rgba: Uint8List(500),
            width: 1,
            height: 1,
          ),
        );

        expect(cache.memoryUsageRatio, 0.5);
      });

      test('returns 0 when empty', () {
        final cache = VideoFrameCache();

        expect(cache.memoryUsageRatio, 0.0);
      });

      test('handles maxMemoryBytes of 0', () {
        final cache = VideoFrameCache(maxMemoryBytes: 0);

        expect(cache.memoryUsageRatio, 0.0);
      });
    });
  });

  group('VideoFrameCacheManager', () {
    tearDown(() {
      VideoFrameCacheManager.dispose();
    });

    test('provides singleton instance', () {
      final cache1 = VideoFrameCacheManager.instance;
      final cache2 = VideoFrameCacheManager.instance;

      expect(identical(cache1, cache2), isTrue);
    });

    test('configure sets custom parameters', () {
      VideoFrameCacheManager.configure(
        maxFrames: 50,
        maxMemoryBytes: 200 * 1024 * 1024,
      );

      final cache = VideoFrameCacheManager.instance;

      expect(cache.maxFrames, 50);
      expect(cache.maxMemoryBytes, 200 * 1024 * 1024);
    });

    test('dispose clears instance', () {
      final cache1 = VideoFrameCacheManager.instance;
      cache1.put(
        'video.mp4',
        0,
        ExtractedFrame(
          frameNumber: 0,
          rgba: Uint8List(10),
          width: 1,
          height: 1,
        ),
      );

      VideoFrameCacheManager.dispose();
      final cache2 = VideoFrameCacheManager.instance;

      expect(identical(cache1, cache2), isFalse);
      expect(cache2.frameCount, 0);
    });
  });

  group('ExtractedFrame', () {
    test('calculates sizeInBytes correctly', () {
      final frame = ExtractedFrame(
        frameNumber: 0,
        rgba: Uint8List(1920 * 1080 * 4),
        width: 1920,
        height: 1080,
      );

      expect(frame.sizeInBytes, 1920 * 1080 * 4);
    });

    test('stores properties correctly', () {
      final rgba = Uint8List(100);
      final frame = ExtractedFrame(
        frameNumber: 42,
        rgba: rgba,
        width: 10,
        height: 10,
      );

      expect(frame.frameNumber, 42);
      expect(frame.rgba, rgba);
      expect(frame.width, 10);
      expect(frame.height, 10);
    });
  });
}
