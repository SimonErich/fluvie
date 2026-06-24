import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';

/// One renderable composition the capture harness can mount by key.
///
/// The registry in `composition_registry.dart` maps CLI keys (for example
/// `demo`) to entries; the harness reads the output geometry from the entry
/// and mounts [build] under its capture boundary.
final class CompositionEntry {
  /// Creates an entry describing one composition and its render geometry.
  const CompositionEntry({
    required this.key,
    required this.width,
    required this.height,
    required this.fps,
    required this.frameCount,
    required this.build,
    this.mediaSources = const <MediaSource>{},
  });

  /// The CLI-facing key (`fluvie render <key>`).
  final String key;

  /// Output width in pixels.
  final int width;

  /// Output height in pixels.
  final int height;

  /// Frames per second of the render.
  final int fps;

  /// Total frames of the render.
  final int frameCount;

  /// Builds the composition widget (mounted under the harness's
  /// `RepaintBoundary` inside a frame-providing scope).
  final Widget Function() build;

  /// Every [MediaSource] this composition declares, gathered before frame 0 by
  /// `collectMediaSources`. The harness pre-resolves these — and
  /// mounts an `ImageResolverScope` — so `Image`/`Clip` paint synchronously from
  /// the first frame with no async pop-in. Empty for a media-less composition.
  final Set<MediaSource> mediaSources;
}
