/// The default target bitrate (bits per second) for an on-device encode.
///
/// Scales with resolution and frame rate at [bitsPerPixel] bits per pixel per
/// frame (0.1 by default, a sane H.264 mobile target), then clamps up to a
/// [minimum] floor so tiny clips still encode cleanly. For 1080p at 30 fps this
/// yields about 6.2 Mbps. Pure and deterministic.
///
/// Throws an [ArgumentError] when a dimension or [fps] is not positive.
int defaultBitRate({
  required int width,
  required int height,
  required int fps,
  double bitsPerPixel = 0.1,
  int minimum = 1000000,
}) {
  if (width <= 0) throw ArgumentError.value(width, 'width', 'must be positive');
  if (height <= 0) throw ArgumentError.value(height, 'height', 'must be positive');
  if (fps <= 0) throw ArgumentError.value(fps, 'fps', 'must be positive');
  final estimate = (width * height * fps * bitsPerPixel).round();
  return estimate < minimum ? minimum : estimate;
}
