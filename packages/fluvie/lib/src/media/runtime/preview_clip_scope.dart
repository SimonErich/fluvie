import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/media/media_source.dart';

/// Preview-only fallback while a newly requested frame is decoding. Capture
/// never mounts this scope and therefore always requires the exact frame.
final class PreviewClipScope extends InheritedWidget {
  /// Publishes currently decoded frames for the preview generation.
  const PreviewClipScope({
    required this.ready,
    required this.revision,
    required super.child,
    super.key,
  });

  /// Frame indices whose rasters can be painted synchronously.
  final Map<MediaSource, Set<int>> ready;

  /// Monotonic revision forcing consumers to resolve a newly decoded frame.
  final int revision;

  /// The closest already decoded frame, until the current request completes.
  static int frameFor(BuildContext context, MediaSource source, int requested) {
    final scope = context.dependOnInheritedWidgetOfExactType<PreviewClipScope>();
    final frames = scope?.ready[source];
    if (frames == null || frames.isEmpty || frames.contains(requested)) return requested;
    return frames.reduce((a, b) => (a - requested).abs() <= (b - requested).abs() ? a : b);
  }

  @override
  bool updateShouldNotify(PreviewClipScope oldWidget) => oldWidget.revision != revision;
}
