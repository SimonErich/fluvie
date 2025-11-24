import 'package:flutter/material.dart';
import '../domain/renderable.dart';
import '../domain/render_config.dart';
import 'clip.dart';

/// The root widget for defining a video composition.
///
/// This widget sets the global properties of the video, such as [fps], [durationInFrames],
/// [width], and [height]. It must be the ancestor of all other Fluvie widgets.
///
/// Example:
/// ```dart
/// VideoComposition(
///   fps: 30,
///   durationInFrames: 300, // 10 seconds
///   child: MyVideoContent(),
/// )
/// ```
class VideoComposition extends InheritedWidget implements Renderable {
  /// Frames per second of the output video.
  final int fps;

  /// Total duration of the video in frames.
  final int durationInFrames;

  /// Width of the output video in pixels. Defaults to 1920.
  final int width;

  /// Height of the output video in pixels. Defaults to 1080.
  final int height;

  const VideoComposition({
    super.key,
    required this.fps,
    required this.durationInFrames,
    this.width = 1920,
    this.height = 1080,
    required super.child,
  });

  static VideoComposition? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VideoComposition>();
  }

  @override
  bool updateShouldNotify(VideoComposition oldWidget) {
    return fps != oldWidget.fps ||
        durationInFrames != oldWidget.durationInFrames ||
        width != oldWidget.width ||
        height != oldWidget.height;
  }

  @override
  RenderConfig toConfig() {
    // VideoComposition.toConfig returns the root config.
    // The RenderService is responsible for populating the clips by walking the tree.
    
    return RenderConfig(
      timeline: TimelineConfig(
        fps: fps,
        durationInFrames: durationInFrames,
        width: width,
        height: height,
      ),
      clips: [], // Populated by RenderService
    );
  }
}
