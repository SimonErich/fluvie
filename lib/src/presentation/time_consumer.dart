import 'package:flutter/material.dart';
import 'video_composition.dart';

/// A widget that rebuilds when the current frame changes.
///
/// Use this widget to create animations based on the current [frame] or [progress].
///
/// Example:
/// ```dart
/// TimeConsumer(
///   builder: (context, frame, progress) {
///     return Opacity(opacity: progress, child: Text('Fading In'));
///   },
/// )
/// ```
class TimeConsumer extends StatelessWidget {
  /// Builder function called with the current context, frame number, and progress (0.0 to 1.0).
  final Widget Function(BuildContext context, int frame, double progress) builder;

  const TimeConsumer({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    // In a real implementation, this would listen to a Driver or InheritedWidget
    // that provides the current frame.
    // Look for a FrameProvider inherited widget.
    final frame = FrameProvider.of(context) ?? 0;
    final composition = VideoComposition.of(context);
    final duration = composition?.durationInFrames ?? 1;
    final progress = frame / duration;

    return builder(context, frame, progress);
  }
}

/// A provider that exposes the current frame to its descendants.
class FrameProvider extends InheritedWidget {
  /// The current frame number.
  final int frame;

  const FrameProvider({
    super.key,
    required this.frame,
    required super.child,
  });

  static int? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FrameProvider>()?.frame;
  }

  @override
  bool updateShouldNotify(FrameProvider oldWidget) {
    return frame != oldWidget.frame;
  }
}
