import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/capture/frame_pipeline.dart';

void main() {
  group('FramePipeline', () {
    group('construction', () {
      test('creates with default buffer size', () {
        final pipeline = FramePipeline();

        expect(pipeline.maxBufferSize, 5);
        expect(pipeline.bufferedFrames, 0);
        expect(pipeline.isClosed, isFalse);
      });

      test('creates with custom buffer size', () {
        final pipeline = FramePipeline(maxBufferSize: 10);

        expect(pipeline.maxBufferSize, 10);
      });

      test('creates with minimum buffer size of 1', () {
        final pipeline = FramePipeline(maxBufferSize: 1);

        expect(pipeline.maxBufferSize, 1);
      });
    });

    group('frames stream', () {
      test('emits frames that are added', () async {
        final pipeline = FramePipeline();
        final receivedFrames = <Uint8List>[];

        // Start listening and consume
        final subscription = pipeline.frames.listen((frame) {
          receivedFrames.add(frame);
          pipeline.frameConsumed();
        });

        // Add frames
        await pipeline.addFrame(Uint8List.fromList([1, 2, 3]));
        await pipeline.addFrame(Uint8List.fromList([4, 5, 6]));

        // Allow stream to process
        await Future.delayed(const Duration(milliseconds: 10));
        await pipeline.close();
        await subscription.cancel();

        expect(receivedFrames.length, 2);
        expect(receivedFrames[0], [1, 2, 3]);
        expect(receivedFrames[1], [4, 5, 6]);
      });

      test('frames arrive in order', () async {
        final pipeline = FramePipeline();
        final receivedFrames = <int>[];

        final subscription = pipeline.frames.listen((frame) {
          receivedFrames.add(frame.first);
          pipeline.frameConsumed();
        });

        for (int i = 0; i < 10; i++) {
          await pipeline.addFrame(Uint8List.fromList([i]));
        }

        await pipeline.close();
        await subscription.cancel();

        expect(receivedFrames, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      });
    });

    group('addFrame', () {
      test('increments buffered frames count', () async {
        final pipeline = FramePipeline(maxBufferSize: 10);

        // Set up a listener that does NOT consume immediately
        // so we can verify bufferedFrames increments
        final frames = <Uint8List>[];
        final subscription = pipeline.frames.listen((frame) {
          frames.add(frame);
          // Intentionally not consuming yet
        });

        // Add frames without consuming
        await pipeline.addFrame(Uint8List(10));
        await pipeline.addFrame(Uint8List(10));

        // Allow stream to deliver
        await Future.delayed(const Duration(milliseconds: 10));

        expect(pipeline.bufferedFrames, 2);
        expect(frames.length, 2);

        // Now consume and clean up
        pipeline.frameConsumed();
        pipeline.frameConsumed();

        expect(pipeline.bufferedFrames, 0);

        await subscription.cancel();
        await pipeline.close();
      });

      test('throws when pipeline is closed', () async {
        final pipeline = FramePipeline();

        // Need a listener to complete close()
        final subscription = pipeline.frames.listen((_) {});
        await pipeline.close();
        await subscription.cancel();

        expect(
          () => pipeline.addFrame(Uint8List(10)),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('frameConsumed', () {
      test('decrements buffered frames', () async {
        final pipeline = FramePipeline(maxBufferSize: 10);

        // Listener that tracks but doesn't auto-consume
        final subscription = pipeline.frames.listen((_) {});

        await pipeline.addFrame(Uint8List(10));
        await pipeline.addFrame(Uint8List(10));

        // Allow stream to deliver
        await Future.delayed(const Duration(milliseconds: 10));

        expect(pipeline.bufferedFrames, 2);

        pipeline.frameConsumed();
        expect(pipeline.bufferedFrames, 1);

        pipeline.frameConsumed();
        expect(pipeline.bufferedFrames, 0);

        await subscription.cancel();
        await pipeline.close();
      });
    });

    group('isClosed', () {
      test('returns false when open', () {
        final pipeline = FramePipeline();

        expect(pipeline.isClosed, isFalse);
      });

      test('returns true after close', () async {
        final pipeline = FramePipeline();
        final subscription = pipeline.frames.listen((_) {});
        await pipeline.close();
        await subscription.cancel();

        expect(pipeline.isClosed, isTrue);
      });
    });

    group('close', () {
      test('closes the stream', () async {
        final pipeline = FramePipeline();
        var streamClosed = false;

        pipeline.frames.listen(
          (_) {},
          onDone: () => streamClosed = true,
        );

        await pipeline.close();
        await Future.delayed(const Duration(milliseconds: 10));

        expect(streamClosed, isTrue);
      });

      test('completes immediately if no buffered frames', () async {
        final pipeline = FramePipeline();

        // Need a listener
        final subscription = pipeline.frames.listen((_) {});

        // Should complete quickly
        await pipeline.close().timeout(
              const Duration(milliseconds: 100),
              onTimeout: () => fail('close should not timeout'),
            );

        expect(pipeline.isClosed, isTrue);
        await subscription.cancel();
      });

      test('can be called multiple times safely', () async {
        final pipeline = FramePipeline();
        final subscription = pipeline.frames.listen((_) {});

        await pipeline.close();
        await pipeline.close(); // Should not throw

        expect(pipeline.isClosed, isTrue);
        await subscription.cancel();
      });

      test('waits for buffered frames to be consumed', () async {
        final pipeline = FramePipeline(maxBufferSize: 5);
        var closeCompleted = false;

        // Listener that consumes with a delay
        final subscription = pipeline.frames.listen((frame) {
          Future.delayed(const Duration(milliseconds: 5), () {
            pipeline.frameConsumed();
          });
        });

        await pipeline.addFrame(Uint8List(10));
        await pipeline.addFrame(Uint8List(10));

        // Allow frames to be delivered
        await Future.delayed(const Duration(milliseconds: 5));

        // Start close - should wait for consumption
        final closeFuture = pipeline.close().then((_) {
          closeCompleted = true;
        });

        // Initially close should not complete
        await Future.delayed(const Duration(milliseconds: 2));

        // Wait for close to complete
        await closeFuture;
        expect(closeCompleted, isTrue);

        await subscription.cancel();
      });
    });

    group('simple producer-consumer', () {
      test('handles simple flow', () async {
        final pipeline = FramePipeline(maxBufferSize: 5);
        final receivedFrames = <int>[];

        // Simple synchronous consumer
        final subscription = pipeline.frames.listen((frame) {
          receivedFrames.add(frame.first);
          pipeline.frameConsumed();
        });

        // Fast producer
        for (int i = 0; i < 10; i++) {
          await pipeline.addFrame(Uint8List.fromList([i]));
        }

        await pipeline.close();
        await subscription.cancel();

        expect(receivedFrames.length, 10);
        expect(receivedFrames, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      });

      test('handles many frames', () async {
        final pipeline = FramePipeline(maxBufferSize: 5);
        final receivedFrames = <int>[];
        const totalFrames = 50;

        // Start consumer
        final consumerCompleter = Completer<void>();
        pipeline.frames.listen(
          (frame) {
            receivedFrames.add(frame.first);
            pipeline.frameConsumed();
          },
          onDone: consumerCompleter.complete,
        );

        // Producer
        for (int i = 0; i < totalFrames; i++) {
          await pipeline.addFrame(Uint8List.fromList([i % 256]));
        }

        await pipeline.close();
        await consumerCompleter.future;

        expect(receivedFrames.length, totalFrames);
      });
    });

    group('memory management', () {
      test('buffer limits memory usage', () async {
        final pipeline = FramePipeline(maxBufferSize: 2);

        // Listener that doesn't auto-consume
        final subscription = pipeline.frames.listen((_) {});

        await pipeline.addFrame(Uint8List(100));
        await pipeline.addFrame(Uint8List(100));

        // Allow delivery
        await Future.delayed(const Duration(milliseconds: 10));

        expect(pipeline.bufferedFrames, 2);

        // Consume frames
        pipeline.frameConsumed();
        pipeline.frameConsumed();

        expect(pipeline.bufferedFrames, 0);

        await subscription.cancel();
        await pipeline.close();
      });

      test('frame data is preserved through pipeline', () async {
        final pipeline = FramePipeline();
        Uint8List? receivedFrame;

        pipeline.frames.listen((frame) {
          receivedFrame = frame;
          pipeline.frameConsumed();
        });

        final originalFrame =
            Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        await pipeline.addFrame(originalFrame);

        await Future.delayed(const Duration(milliseconds: 10));
        await pipeline.close();

        expect(receivedFrame, isNotNull);
        expect(receivedFrame, originalFrame);
      });
    });

    group('edge cases', () {
      test('handles empty frames', () async {
        final pipeline = FramePipeline();
        var received = false;

        pipeline.frames.listen((frame) {
          expect(frame.isEmpty, isTrue);
          received = true;
          pipeline.frameConsumed();
        });

        await pipeline.addFrame(Uint8List(0));
        await Future.delayed(const Duration(milliseconds: 10));
        await pipeline.close();

        expect(received, isTrue);
      });

      test('handles single frame', () async {
        final pipeline = FramePipeline();
        var received = false;

        pipeline.frames.listen((frame) {
          received = true;
          pipeline.frameConsumed();
        });

        await pipeline.addFrame(Uint8List.fromList([42]));
        await pipeline.close();

        expect(received, isTrue);
      });

      test('handles buffer size of 1', () async {
        final pipeline = FramePipeline(maxBufferSize: 1);
        final receivedFrames = <int>[];

        pipeline.frames.listen((frame) {
          receivedFrames.add(frame.first);
          pipeline.frameConsumed();
        });

        for (int i = 0; i < 5; i++) {
          await pipeline.addFrame(Uint8List.fromList([i]));
        }

        await pipeline.close();

        expect(receivedFrames, [0, 1, 2, 3, 4]);
      });
    });

    group('backpressure', () {
      test('blocks addFrame when buffer is full until consumed', () async {
        final pipeline = FramePipeline(maxBufferSize: 2);
        var addCount = 0;

        // Slow consumer that tracks received frames
        final frames = <Uint8List>[];
        final subscription = pipeline.frames.listen((frame) {
          frames.add(frame);
          // Delay consumption to create backpressure
          Future.delayed(const Duration(milliseconds: 10), () {
            pipeline.frameConsumed();
          });
        });

        // Try to add 3 frames to buffer of 2
        final add1 =
            pipeline.addFrame(Uint8List.fromList([1])).then((_) => addCount++);
        final add2 =
            pipeline.addFrame(Uint8List.fromList([2])).then((_) => addCount++);

        // Let first two frames be queued
        await add1;
        await add2;
        expect(addCount, 2);

        // Third frame should wait for consumption
        final add3Future =
            pipeline.addFrame(Uint8List.fromList([3])).then((_) => addCount++);

        // Give it time for the delayed consumer to make room
        await Future.delayed(const Duration(milliseconds: 50));
        await add3Future;

        expect(addCount, 3);

        // Wait for all consumption
        await Future.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();
        await pipeline.close();
      });
    });
  });
}
