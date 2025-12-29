import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/capture/frame_sequencer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FrameSequencer', () {
    testWidgets('can be created with a GlobalKey', (tester) async {
      final key = GlobalKey();
      final sequencer = FrameSequencer(key);
      expect(sequencer, isNotNull);
      expect(sequencer.repaintBoundaryKey, equals(key));
    });

    testWidgets('captures frame from RepaintBoundary', (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Container(
              width: 100,
              height: 100,
              color: Colors.red,
            ),
          ),
        ),
      );

      final sequencer = FrameSequencer(key);
      final image = await sequencer.captureFrame(pixelRatio: 1.0);

      expect(image, isNotNull);
      // The actual pixel dimensions depend on the device pixel ratio in the test environment
      expect(image.width, greaterThan(0));
      expect(image.height, greaterThan(0));
    });

    testWidgets('captures frame at specified pixel ratio', (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Container(
              width: 50,
              height: 50,
              color: Colors.blue,
            ),
          ),
        ),
      );

      final sequencer = FrameSequencer(key);
      // Capture at pixelRatio 1.0 first
      final image1 = await sequencer.captureFrame(pixelRatio: 1.0);
      // Capture at pixelRatio 2.0
      final image2 = await sequencer.captureFrame(pixelRatio: 2.0);

      expect(image1, isNotNull);
      expect(image2, isNotNull);
      // At 2x pixel ratio, the image should be twice the size
      expect(image2.width, equals(image1.width * 2));
      expect(image2.height, equals(image1.height * 2));
    });

    testWidgets('throws when RepaintBoundary not found', (tester) async {
      final key = GlobalKey();
      // Don't pump any widget with this key

      final sequencer = FrameSequencer(key);

      expect(
        () => sequencer.captureFrame(pixelRatio: 1.0),
        throwsException,
      );
    });

    // Note: Tests for captureFrameRaw and captureFrameRawExact are skipped
    // because they can cause the test framework to hang due to stream handling
    // issues with toByteData(). These methods are tested via integration tests.
  });
}
