import 'package:flutter/material.dart';
import '../domain/renderable.dart';
import '../domain/render_config.dart';
import 'sync_anchor_registry.dart';

/// Data provided by [VideoComposition] to descendant widgets.
///
/// Access this via [VideoComposition.of(context)].
class VideoCompositionData {
  /// Frames per second of the output video.
  final int fps;

  /// Total duration of the video in frames.
  final int durationInFrames;

  /// Width of the output video in pixels.
  final int width;

  /// Height of the output video in pixels.
  final int height;

  /// Encoding configuration for video output.
  final EncodingConfig? encoding;

  const VideoCompositionData({
    required this.fps,
    required this.durationInFrames,
    required this.width,
    required this.height,
    this.encoding,
  });
}

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
class VideoComposition extends StatefulWidget implements Renderable {
  /// Frames per second of the output video.
  final int fps;

  /// Total duration of the video in frames.
  final int durationInFrames;

  /// Width of the output video in pixels. Defaults to 1920.
  final int width;

  /// Height of the output video in pixels. Defaults to 1080.
  final int height;

  /// Encoding configuration for video output.
  final EncodingConfig? encoding;

  /// The child widget.
  final Widget child;

  const VideoComposition({
    super.key,
    required this.fps,
    required this.durationInFrames,
    this.width = 1920,
    this.height = 1080,
    this.encoding,
    required this.child,
  });

  /// Retrieves the composition data from the nearest [VideoComposition] ancestor.
  ///
  /// Returns null if no [VideoComposition] is found in the widget tree.
  static VideoCompositionData? of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_VideoCompositionInherited>();
    return inherited?.data;
  }

  @override
  State<VideoComposition> createState() => _VideoCompositionState();

  @override
  RenderConfig toConfig() {
    return RenderConfig(
      timeline: TimelineConfig(
        fps: fps,
        durationInFrames: durationInFrames,
        width: width,
        height: height,
      ),
      sequences: [], // Populated by RenderService
      encoding: encoding,
    );
  }
}

class _VideoCompositionState extends State<VideoComposition> {
  late final SyncAnchorRegistryData _syncAnchorRegistry;

  @override
  void initState() {
    super.initState();
    _syncAnchorRegistry = SyncAnchorRegistryData();
  }

  @override
  void dispose() {
    _syncAnchorRegistry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = VideoCompositionData(
      fps: widget.fps,
      durationInFrames: widget.durationInFrames,
      width: widget.width,
      height: widget.height,
      encoding: widget.encoding,
    );

    return _VideoCompositionInherited(
      data: data,
      child: SyncAnchorRegistry(data: _syncAnchorRegistry, child: widget.child),
    );
  }
}

/// Internal InheritedWidget that provides composition data.
class _VideoCompositionInherited extends InheritedWidget {
  final VideoCompositionData data;

  const _VideoCompositionInherited({required this.data, required super.child});

  @override
  bool updateShouldNotify(_VideoCompositionInherited oldWidget) {
    return data.fps != oldWidget.data.fps ||
        data.durationInFrames != oldWidget.data.durationInFrames ||
        data.width != oldWidget.data.width ||
        data.height != oldWidget.data.height ||
        data.encoding != oldWidget.data.encoding;
  }
}
