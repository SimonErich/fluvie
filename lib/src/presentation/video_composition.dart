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
    // We need to traverse the element tree to find Clips.
    // Since this method is called outside of the build phase (usually),
    // we might need a context or a way to access the element tree.
    // However, Renderable.toConfig() doesn't take a context.
    // This implies we need to capture the config during build or have a mechanism to walk.
    
    // For now, we will assume this method is called when we have access to the Element.
    // But wait, VideoComposition is a Widget. It doesn't have state or element access directly in this method.
    // The RenderService will likely use an ElementVisitor on the root of the tree.
    
    // So VideoComposition.toConfig might just return the root config, 
    // and the RenderService is responsible for populating the clips by walking the tree.
    
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
