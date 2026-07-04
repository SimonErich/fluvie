part of 'defaults.dart';

/// The package's render defaults: the frame rate and canvas size every render
/// entry point falls back to when the caller sets none.
///
/// These are the *render* defaults, distinct from the animation [Defaults]
/// cascade: they parameterize the canvas and clock, not motion. One named
/// constant per value keeps `Video`, the render pipeline, and the on-device
/// encoders agreeing without repeating the number.
abstract final class VideoDefaults {
  /// Frames per second when no `fps:` is given — 30, the streaming norm.
  static const int fps = 30;

  /// The canvas's longer side in pixels when no size is given — 1920, so the
  /// default vertical canvas is 1080×1920 and the default landscape canvas is
  /// 1920×1080.
  static const int longEdge = 1920;
}
