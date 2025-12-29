import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/encoding/video_frame_cache.dart';
import 'package:fluvie/src/encoding/frame_extraction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoFrameCache', () {
    late VideoFrameCache cache;

    setUp(() {
      cache = VideoFrameCache(maxFrames: 100);
    });

    tearDown(() {
      cache.clearAll();
    });

    test('can be created with default settings', () {
      final defaultCache = VideoFrameCache();
      expect(defaultCache, isNotNull);
    });

    test('can be created with custom max frames', () {
      final customCache = VideoFrameCache(maxFrames: 50);
      expect(customCache, isNotNull);
    });

    test('can be created with custom max memory', () {
      final customCache = VideoFrameCache(maxMemoryBytes: 100 * 1024 * 1024);
      expect(customCache, isNotNull);
    });

    test('put and get frame works correctly', () {
      final frame = _createMockFrame(0, 100, 100);
      cache.put('video.mp4', 0, frame);

      final retrieved = cache.get('video.mp4', 0);
      expect(retrieved, isNotNull);
      expect(retrieved!.width, equals(100));
      expect(retrieved.height, equals(100));
    });

    test('get returns null for non-existent frame', () {
      final result = cache.get('nonexistent.mp4', 0);
      expect(result, isNull);
    });

    test('has returns true for cached frame', () {
      final frame = _createMockFrame(5, 50, 50);
      cache.put('test.mp4', 5, frame);

      expect(cache.has('test.mp4', 5), isTrue);
    });

    test('has returns false for non-cached frame', () {
      expect(cache.has('test.mp4', 999), isFalse);
    });

    test('clearAll removes all frames', () {
      cache.put('a.mp4', 0, _createMockFrame(0, 10, 10));
      cache.put('b.mp4', 0, _createMockFrame(0, 10, 10));

      cache.clearAll();

      expect(cache.has('a.mp4', 0), isFalse);
      expect(cache.has('b.mp4', 0), isFalse);
    });

    test('clearVideo removes only frames for specific video', () {
      cache.put('a.mp4', 0, _createMockFrame(0, 10, 10));
      cache.put('a.mp4', 1, _createMockFrame(1, 10, 10));
      cache.put('b.mp4', 0, _createMockFrame(0, 10, 10));

      cache.clearVideo('a.mp4');

      expect(cache.has('a.mp4', 0), isFalse);
      expect(cache.has('a.mp4', 1), isFalse);
      expect(cache.has('b.mp4', 0), isTrue);
    });

    test('evicts oldest frames when max frames exceeded', () {
      // Cache with max 3 frames
      final smallCache = VideoFrameCache(maxFrames: 3);

      smallCache.put('v.mp4', 0, _createMockFrame(0, 10, 10));
      smallCache.put('v.mp4', 1, _createMockFrame(1, 10, 10));
      smallCache.put('v.mp4', 2, _createMockFrame(2, 10, 10));

      // This should evict frame 0
      smallCache.put('v.mp4', 3, _createMockFrame(3, 10, 10));

      expect(smallCache.has('v.mp4', 0), isFalse);
      expect(smallCache.has('v.mp4', 1), isTrue);
      expect(smallCache.has('v.mp4', 2), isTrue);
      expect(smallCache.has('v.mp4', 3), isTrue);

      smallCache.clearAll();
    });

    test('frameCount returns current number of cached frames', () {
      expect(cache.frameCount, equals(0));

      cache.put('v.mp4', 0, _createMockFrame(0, 10, 10));
      expect(cache.frameCount, equals(1));

      cache.put('v.mp4', 1, _createMockFrame(1, 10, 10));
      expect(cache.frameCount, equals(2));

      cache.clearAll();
      expect(cache.frameCount, equals(0));
    });

    test('memoryUsage tracks memory correctly', () {
      expect(cache.memoryUsage, equals(0));

      // 10x10 RGBA = 400 bytes
      cache.put('v.mp4', 0, _createMockFrame(0, 10, 10));
      expect(cache.memoryUsage, equals(400));

      // 20x20 RGBA = 1600 bytes
      cache.put('v.mp4', 1, _createMockFrame(1, 20, 20));
      expect(cache.memoryUsage, equals(2000));

      cache.clearAll();
      expect(cache.memoryUsage, equals(0));
    });
  });

  group('VideoFrameCacheManager', () {
    tearDown(() {
      VideoFrameCacheManager.dispose();
    });

    test('instance returns singleton', () {
      final a = VideoFrameCacheManager.instance;
      final b = VideoFrameCacheManager.instance;
      expect(identical(a, b), isTrue);
    });

    test('configure allows setting max frames', () {
      VideoFrameCacheManager.configure(maxFrames: 500);
      final cache = VideoFrameCacheManager.instance;
      expect(cache, isNotNull);
    });

    test('configure allows setting max memory', () {
      VideoFrameCacheManager.configure(maxMemoryBytes: 100 * 1024 * 1024);
      final cache = VideoFrameCacheManager.instance;
      expect(cache, isNotNull);
    });
  });

  group('ExtractedFrame', () {
    test('can be created from rgba bytes', () {
      final rgba = Uint8List.fromList(List.filled(100 * 100 * 4, 128));
      final frame = ExtractedFrame(
        frameNumber: 0,
        rgba: rgba,
        width: 100,
        height: 100,
      );

      expect(frame.width, equals(100));
      expect(frame.height, equals(100));
      expect(frame.rgba.length, equals(100 * 100 * 4));
      expect(frame.frameNumber, equals(0));
    });

    test('sizeInBytes returns correct size', () {
      final rgba = Uint8List.fromList(List.filled(50 * 50 * 4, 255));
      final frame = ExtractedFrame(
        frameNumber: 1,
        rgba: rgba,
        width: 50,
        height: 50,
      );

      expect(frame.sizeInBytes, equals(50 * 50 * 4));
    });

    test('toImage returns valid ui.Image', () async {
      final rgba = Uint8List.fromList(List.filled(10 * 10 * 4, 255));
      final frame = ExtractedFrame(
        frameNumber: 0,
        rgba: rgba,
        width: 10,
        height: 10,
      );

      final image = await frame.toImage();
      expect(image, isNotNull);
      expect(image.width, equals(10));
      expect(image.height, equals(10));
    });
  });
}

ExtractedFrame _createMockFrame(int frameNumber, int width, int height) {
  final rgba = Uint8List.fromList(List.filled(width * height * 4, 128));
  return ExtractedFrame(
    frameNumber: frameNumber,
    rgba: rgba,
    width: width,
    height: height,
  );
}
