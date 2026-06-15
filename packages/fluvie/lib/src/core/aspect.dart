import 'package:fluvie/src/core/video_size.dart';

/// The aspect-ratio family a video is rendered for.
///
/// One `Adaptive` definition can branch per aspect, and `render` picks the
/// variant: `render(video, aspect: Aspect.square)`. Elements can also branch
/// at build time via `AspectScope.of(context)`.
enum Aspect {
  /// Vertical 9:16 — Reels, Shorts, TikTok, Stories. The default aspect when
  /// no `AspectScope` is above (matching the canonical [VideoSize.reels]).
  reels,

  /// Square 1:1 — feed posts.
  square,

  /// Horizontal 16:9 — YouTube, presentations, TV.
  landscape,

  /// Vertical 4:5 — the tall feed-post format.
  portrait45;

  /// The default aspect when no `AspectScope` is mounted: vertical [reels],
  /// matching `VideoSize.reels` (the canonical 1080×1920 canvas).
  static const Aspect fallback = Aspect.reels;

  /// The canvas [VideoSize] for this aspect with [longEdge] pixels on its
  /// longer side, scaled to the family's ratio.
  ///
  /// [landscape] is 16:9 with [longEdge] as the width; [reels] (9:16) and
  /// [portrait45] (4:5) are tall, so [longEdge] is the height; [square] is
  /// [longEdge] on both axes. The shorter edge is derived from the ratio and
  /// rounded to an even number so every result is yuv420p-safe.
  ///
  /// Throws an [ArgumentError] when [longEdge] is not positive.
  VideoSize sizeFor(int longEdge) {
    if (longEdge <= 0) {
      throw ArgumentError.value(longEdge, 'longEdge', 'must be positive');
    }
    return switch (this) {
      Aspect.landscape => VideoSize(longEdge, _even(longEdge * 9 / 16)),
      Aspect.reels => VideoSize(_even(longEdge * 9 / 16), longEdge),
      Aspect.portrait45 => VideoSize(_even(longEdge * 4 / 5), longEdge),
      Aspect.square => VideoSize(longEdge, longEdge),
    };
  }

  /// Rounds [value] to the nearest even integer (yuv420p chroma subsampling
  /// halves both dimensions, so an odd edge would be rejected downstream).
  static int _even(double value) {
    final rounded = value.round();
    return rounded.isEven ? rounded : rounded + 1;
  }
}
