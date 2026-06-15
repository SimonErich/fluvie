import 'package:flutter/foundation.dart';

/// One captured frame: raw RGBA8888 pixels plus the metadata the encoder
/// needs to place them in the stream.
///
/// The bytes are exactly what `Image.toByteData(format: rawRgba)` produced —
/// row-major, four bytes per pixel, no padding — so [rgba] can be appended to
/// the frames file verbatim. Construction validates that the byte length
/// matches `width * height * 4`; a mismatch is a programming error
/// ([ArgumentError]), not a render failure.
///
/// Value equality covers the metadata *and* the pixel bytes, which is what
/// lets determinism tests assert "same frame twice" directly on [RawFrame]s.
@immutable
final class RawFrame {
  /// Creates a frame at [frameIndex] with [width]x[height] pixels in [rgba].
  ///
  /// Throws an [ArgumentError] when `rgba.length != width * height * 4`.
  RawFrame({
    required this.frameIndex,
    required this.width,
    required this.height,
    required this.rgba,
  }) {
    final expected = width * height * 4;
    if (rgba.length != expected) {
      throw ArgumentError.value(
        rgba.length,
        'rgba',
        'must hold exactly width*height*4 = $expected bytes for ${width}x$height',
      );
    }
  }

  /// The zero-based index of this frame in the render.
  final int frameIndex;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Raw RGBA8888 pixel data, row-major, `width * height * 4` bytes.
  final Uint8List rgba;

  /// The pixel payload size in bytes (`width * height * 4`).
  int get byteLength => width * height * 4;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RawFrame &&
        other.frameIndex == frameIndex &&
        other.width == width &&
        other.height == height &&
        _bytesEqual(other.rgba, rgba);
  }

  @override
  int get hashCode => Object.hash(frameIndex, width, height, Object.hashAll(rgba));

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
