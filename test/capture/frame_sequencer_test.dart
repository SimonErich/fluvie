import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/capture/frame_sequencer.dart';
import 'package:fluvie/src/exceptions/fluvie_exceptions.dart';

void main() {
  group('FrameSequencer', () {
    group('construction', () {
      test('creates with GlobalKey', () {
        final key = GlobalKey();
        final sequencer = FrameSequencer(key);

        expect(sequencer, isNotNull);
        expect(sequencer.repaintBoundaryKey, key);
      });
    });

    group('captureFrame', () {
      testWidgets('captures frame from RepaintBoundary', (tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 100,
              height: 100,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ));

        final sequencer = FrameSequencer(key);
        final image = await sequencer.captureFrame();

        expect(image, isNotNull);
        expect(image.width, greaterThan(0));
        expect(image.height, greaterThan(0));

        image.dispose();
      });

      testWidgets('respects pixel ratio', (tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 100,
              height: 100,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ));

        final sequencer = FrameSequencer(key);

        final image1x = await sequencer.captureFrame(pixelRatio: 1.0);
        final image2x = await sequencer.captureFrame(pixelRatio: 2.0);

        // 2x should be twice the dimensions
        expect(image2x.width, image1x.width * 2);
        expect(image2x.height, image1x.height * 2);

        image1x.dispose();
        image2x.dispose();
      });

      testWidgets('throws when boundary not found', (tester) async {
        final key = GlobalKey(); // Key not attached to any widget

        final sequencer = FrameSequencer(key);

        expect(
          () => sequencer.captureFrame(),
          throwsA(isA<FrameCaptureException>()),
        );
      });
    });

    // Note: captureFrameRaw and captureFrameRawExact tests that call toByteData()
    // hang in the Flutter test environment. These should be tested via integration
    // tests with real rendering. The captureFrame() tests above verify that frame
    // capture works; the byte conversion is a Flutter engine operation.

    group('captureFrameRaw', () {
      testWidgets('throws when boundary not found', (tester) async {
        final key = GlobalKey();

        final sequencer = FrameSequencer(key);

        expect(
          () => sequencer.captureFrameRaw(pixelRatio: 1.0),
          throwsA(isA<FrameCaptureException>()),
        );
      });
    });

    group('captureFrameRawExact', () {
      testWidgets('throws when boundary not found', (tester) async {
        final key = GlobalKey();

        final sequencer = FrameSequencer(key);

        expect(
          () => sequencer.captureFrameRawExact(
            pixelRatio: 1.0,
            targetWidth: 100,
            targetHeight: 100,
          ),
          throwsA(isA<FrameCaptureException>()),
        );
      });
    });

    group('edge cases', () {
      testWidgets('handles very small widgets', (tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 1,
              height: 1,
              child: ColoredBox(color: Colors.black),
            ),
          ),
        ));

        final sequencer = FrameSequencer(key);
        final image = await sequencer.captureFrame(pixelRatio: 1.0);

        expect(image, isNotNull);
        expect(image.width, greaterThan(0));
        expect(image.height, greaterThan(0));

        image.dispose();
      });

      testWidgets('handles nested widgets', (tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Container(
              width: 100,
              height: 100,
              color: Colors.white,
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.red,
                  child: const Center(
                    child: Text('Hi'),
                  ),
                ),
              ),
            ),
          ),
        ));

        final sequencer = FrameSequencer(key);
        final image = await sequencer.captureFrame();

        expect(image.width, greaterThan(0));
        expect(image.height, greaterThan(0));

        image.dispose();
      });

      testWidgets('handles widgets with gradients', (tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.blue],
                ),
              ),
            ),
          ),
        ));

        final sequencer = FrameSequencer(key);
        final image = await sequencer.captureFrame(pixelRatio: 1.0);

        expect(image, isNotNull);
        expect(image.width, greaterThan(0));
        expect(image.height, greaterThan(0));

        image.dispose();
      });

      testWidgets('handles transparent widgets', (tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Container(
              width: 100,
              height: 100,
              color: Colors.transparent,
            ),
          ),
        ));

        final sequencer = FrameSequencer(key);
        final image = await sequencer.captureFrame(pixelRatio: 1.0);

        expect(image, isNotNull);
        expect(image.width, greaterThan(0));
        expect(image.height, greaterThan(0));

        image.dispose();
      });
    });
  });

  group('FrameCaptureException', () {
    test('creates with message only', () {
      final exception = FrameCaptureException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.boundaryKey, isNull);
    });

    test('creates with message and boundaryKey', () {
      final exception = FrameCaptureException(
        'Test error',
        boundaryKey: 'key123',
      );

      expect(exception.message, 'Test error');
      expect(exception.boundaryKey, 'key123');
    });

    test('toString includes message', () {
      final exception = FrameCaptureException('Frame capture failed');

      expect(exception.toString(), contains('Frame capture failed'));
    });

    test('toString includes boundaryKey when present', () {
      final exception = FrameCaptureException(
        'Frame capture failed',
        boundaryKey: 'GlobalKey#12345',
      );

      final str = exception.toString();
      expect(str, contains('Frame capture failed'));
      expect(str, contains('GlobalKey#12345'));
    });
  });
}
