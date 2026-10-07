/// The most pixels an untrusted render's canvas may span on either axis (8K).
/// A per-axis bound is checked FIRST and BEFORE any product, so a huge width or
/// height cannot overflow a 64-bit multiply to a small (or negative) value and
/// slip past — the whole reason width*height as the primary check is unsafe.
const int _maxUntrustedDimension = 7680;

/// The most frames an untrusted render may produce. With both axes bounded
/// above, this keeps the frame-bytes product far below the 64-bit ceiling.
const int _maxUntrustedFrames = 60 * 60 * 4;

/// The most raw-frame bytes an untrusted render may accumulate on disk
/// (width*height*4 per frame, summed over the frame count). Bounds a runaway
/// render's disk use independently of the wall-clock timeout.
const int _maxUntrustedFrameBytes = 10 * 1024 * 1024 * 1024;

/// Rejects an [untrusted] render whose final [width]x[height] canvas or total
/// frame size is out of bounds, before the frame loop allocates anything. A
/// trusted render (untrusted == false) is never bounded. Pure and directly
/// unit-testable; the render host reads its untrusted flag from a build define.
void assertRenderWithinBounds({
  required bool untrusted,
  required int width,
  required int height,
  required int frameCount,
}) {
  if (!untrusted) return;
  // Per-axis, before any multiply: an overflowing width*height must not wrap to
  // a value under the limit. Both axes bounded, the products below are safe.
  if (width <= 0 ||
      height <= 0 ||
      width > _maxUntrustedDimension ||
      height > _maxUntrustedDimension) {
    throw StateError(
      'Untrusted render canvas ${width}x$height exceeds the '
      '${_maxUntrustedDimension}px per-axis limit.',
    );
  }
  if (frameCount < 0 || frameCount > _maxUntrustedFrames) {
    throw StateError(
      'Untrusted render of $frameCount frames exceeds the '
      '$_maxUntrustedFrames-frame limit.',
    );
  }
  if (width * height * 4 * frameCount > _maxUntrustedFrameBytes) {
    throw StateError(
      'Untrusted render of $frameCount ${width}x$height frames exceeds the '
      '$_maxUntrustedFrameBytes-byte limit.',
    );
  }
}
