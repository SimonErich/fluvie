import 'dart:typed_data';

/// One source frame in RGBA8888 format, independent of Flutter.
final class MediaFrame {
  /// Creates and validates a raster with exactly four bytes per pixel.
  MediaFrame({
    required this.frameIndex,
    required this.width,
    required this.height,
    required this.rgba,
  }) {
    if (width <= 0 || height <= 0 || frameIndex < 0 || rgba.length != width * height * 4) {
      throw ArgumentError(
        'Expected a nonnegative frame index, positive dimensions and width*height*4 RGBA bytes.',
      );
    }
  }

  /// Source frame index.
  final int frameIndex;

  /// Pixel width.
  final int width;

  /// Pixel height.
  final int height;

  /// Row-major pixels, with alpha preserved.
  final Uint8List rgba;
}
