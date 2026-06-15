import 'package:meta/meta.dart';

/// A video canvas size in pixels, with presets for the common aspect ratios.
///
/// Pass one to `Video(size: VideoSize.reels)` instead of spelling out
/// `width`/`height`; an explicit preset always wins over the loose
/// dimension parameters. Sizes are plain values — equality compares
/// dimensions, so two `VideoSize(1080, 1920)` are interchangeable.
@immutable
final class VideoSize {
  /// Creates a canvas of [width] × [height] pixels; both must be positive.
  const VideoSize(this.width, this.height)
    : assert(width > 0, 'VideoSize.width must be positive, got $width'),
      assert(height > 0, 'VideoSize.height must be positive, got $height');

  /// The canvas width in pixels.
  final int width;

  /// The canvas height in pixels.
  final int height;

  /// 1080 × 1920 — the canonical vertical format (Reels, Shorts, TikTok).
  static const VideoSize reels = VideoSize(1080, 1920);

  /// An alias of [reels]: stories share the canonical vertical format.
  static const VideoSize story = reels;

  /// 1080 × 1080 — the square format for feeds.
  static const VideoSize square = VideoSize(1080, 1080);

  /// 1920 × 1080 — landscape full HD.
  static const VideoSize hd = VideoSize(1920, 1080);

  /// 3840 × 2160 — landscape 4K UHD.
  static const VideoSize fourK = VideoSize(3840, 2160);

  @override
  bool operator ==(Object other) =>
      other is VideoSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(VideoSize, width, height);

  @override
  String toString() => 'VideoSize(${width}x$height)';
}
