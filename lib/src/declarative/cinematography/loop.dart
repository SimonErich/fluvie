import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';

/// A widget that loops its child's animation.
///
/// [Loop] creates a looping effect by resetting the frame context
/// for its children. This allows animations to repeat without
/// manually managing timing.
///
/// Example:
/// ```dart
/// Loop(
///   loopDuration: 60, // Loop every 60 frames
///   cycles: 3,        // Repeat 3 times
///   child: AnimatedProp(
///     animation: PropAnimation.rotate(start: 0, end: 2 * pi),
///     duration: 60,
///     child: MySpinner(),
///   ),
/// )
/// ```
class Loop extends StatelessWidget {
  /// The child widget to loop.
  final Widget child;

  /// Duration of one loop cycle in frames.
  final int loopDuration;

  /// Number of cycles to repeat.
  ///
  /// If null, loops indefinitely until the parent scene ends.
  final int? cycles;

  /// The frame at which looping starts.
  final int startFrame;

  /// Whether to ping-pong (reverse every other cycle).
  final bool pingPong;

  /// Creates a loop widget.
  const Loop({
    super.key,
    required this.child,
    required this.loopDuration,
    this.cycles,
    this.startFrame = 0,
    this.pingPong = false,
  });

  /// Creates an infinite loop.
  const Loop.infinite({
    super.key,
    required this.child,
    required this.loopDuration,
    this.startFrame = 0,
    this.pingPong = false,
  }) : cycles = null;

  /// Creates a ping-pong loop that reverses every other cycle.
  const Loop.pingPong({
    super.key,
    required this.child,
    required this.loopDuration,
    this.cycles,
    this.startFrame = 0,
  }) : pingPong = true;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final relativeFrame = frame - startFrame;

        // Before loop starts
        if (relativeFrame < 0) {
          return _buildWithLocalFrame(0);
        }

        // Calculate which cycle we're in
        final cycleIndex = relativeFrame ~/ loopDuration;

        // Check if we've exceeded the cycle count
        if (cycles != null && cycleIndex >= cycles!) {
          // Return final state
          final finalFrame = pingPong && cycles!.isOdd ? 0 : loopDuration - 1;
          return _buildWithLocalFrame(finalFrame);
        }

        // Calculate local frame within the cycle
        var localFrame = relativeFrame % loopDuration;

        // Handle ping-pong
        if (pingPong && cycleIndex.isOdd) {
          localFrame = loopDuration - 1 - localFrame;
        }

        return _buildWithLocalFrame(localFrame);
      },
    );
  }

  Widget _buildWithLocalFrame(int localFrame) {
    // Provide a new frame context for children
    return _LoopFrameProvider(localFrame: localFrame, child: child);
  }

  /// Calculates total duration of all loops in frames.
  int get totalDuration {
    if (cycles == null) return -1; // Infinite
    return loopDuration * cycles!;
  }
}

/// Provides a local frame context for looped content.
class _LoopFrameProvider extends InheritedWidget {
  final int localFrame;

  const _LoopFrameProvider({required this.localFrame, required super.child});

  static int? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_LoopFrameProvider>()
        ?.localFrame;
  }

  @override
  bool updateShouldNotify(_LoopFrameProvider oldWidget) {
    return localFrame != oldWidget.localFrame;
  }
}

/// Extension to get the local loop frame if inside a [Loop].
extension LoopFrameExtension on BuildContext {
  /// Gets the local frame within the current loop, or null if not in a loop.
  int? get loopFrame => _LoopFrameProvider.of(this);
}
