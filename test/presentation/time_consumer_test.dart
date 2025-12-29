import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';

void main() {
  group('TimeConsumer', () {
    testWidgets('calls builder with frame and progress', (tester) async {
      int? capturedFrame;
      double? capturedProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 100,
            child: FrameProvider(
              frame: 50,
              child: TimeConsumer(
                builder: (context, frame, progress) {
                  capturedFrame = frame;
                  capturedProgress = progress;
                  return Text('Frame: $frame');
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedFrame, equals(50));
      expect(capturedProgress, equals(0.5));
    });

    testWidgets('calculates progress based on composition duration', (tester) async {
      double? capturedProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 200,
            child: FrameProvider(
              frame: 100,
              child: TimeConsumer(
                builder: (context, frame, progress) {
                  capturedProgress = progress;
                  return Container();
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedProgress, equals(0.5));
    });

    testWidgets('provides 0 progress at frame 0', (tester) async {
      double? capturedProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 100,
            child: FrameProvider(
              frame: 0,
              child: TimeConsumer(
                builder: (context, frame, progress) {
                  capturedProgress = progress;
                  return Container();
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedProgress, equals(0.0));
    });

    testWidgets('provides 1.0 progress at end frame', (tester) async {
      double? capturedProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 100,
            child: FrameProvider(
              frame: 100,
              child: TimeConsumer(
                builder: (context, frame, progress) {
                  capturedProgress = progress;
                  return Container();
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedProgress, equals(1.0));
    });

    testWidgets('defaults to frame 0 without FrameProvider', (tester) async {
      int? capturedFrame;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 100,
            child: TimeConsumer(
              builder: (context, frame, progress) {
                capturedFrame = frame;
                return Text('Frame: $frame');
              },
            ),
          ),
        ),
      );

      expect(capturedFrame, equals(0));
    });

    testWidgets('works without VideoComposition ancestor', (tester) async {
      int? capturedFrame;
      double? capturedProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: TimeConsumer(
            builder: (context, frame, progress) {
              capturedFrame = frame;
              capturedProgress = progress;
              return Text('Frame: $frame');
            },
          ),
        ),
      );

      // Without VideoComposition, defaults to frame 0 and progress 0
      expect(capturedFrame, equals(0));
      expect(capturedProgress, equals(0.0));
    });

    testWidgets('rebuilds when FrameProvider frame changes', (tester) async {
      final frameKey = GlobalKey<_FrameProviderWrapperState>();
      final frameHistory = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: VideoComposition(
            fps: 30,
            durationInFrames: 100,
            child: _FrameProviderWrapper(
              key: frameKey,
              initialFrame: 10,
              child: TimeConsumer(
                builder: (context, frame, progress) {
                  frameHistory.add(frame);
                  return Text('Frame: $frame');
                },
              ),
            ),
          ),
        ),
      );

      expect(frameHistory.last, equals(10));

      frameKey.currentState!.setFrame(20);
      await tester.pump();

      expect(frameHistory.last, equals(20));
    });
  });
}

// Helper widget for testing frame changes
class _FrameProviderWrapper extends StatefulWidget {
  final int initialFrame;
  final Widget child;

  const _FrameProviderWrapper({
    super.key,
    required this.initialFrame,
    required this.child,
  });

  @override
  State<_FrameProviderWrapper> createState() => _FrameProviderWrapperState();
}

class _FrameProviderWrapperState extends State<_FrameProviderWrapper> {
  late int _frame;

  @override
  void initState() {
    super.initState();
    _frame = widget.initialFrame;
  }

  void setFrame(int frame) {
    setState(() {
      _frame = frame;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FrameProvider(
      frame: _frame,
      child: widget.child,
    );
  }
}
