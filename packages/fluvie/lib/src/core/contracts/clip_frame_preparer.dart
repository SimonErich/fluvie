import 'package:fluvie/src/core/media/media_source.dart';

/// An optional capability a `MediaResolver` advertises when it streams clip
/// frames from a disk store instead of holding every decoded frame in memory.
///
/// A resolver that implements this is driven by the capture loop: the
/// pre-pass registers each clip's resampling plan with [registerClipPlan], and
/// the loop calls [prepareClipFrames] just before it pumps composition frame
/// `n` so the one source frame that frame paints is decoded and warm. The
/// resolver keeps only a small, bounded window of decoded frames, so a long or
/// full-resolution clip never has to fit its whole decoded self in memory.
///
/// Resolvers that decode everything up front (the browser path, fakes) simply
/// do not implement this; the loop then skips the decode-ahead step and their
/// behavior is unchanged.
abstract interface class ClipFramePreparer {
  /// Records how [source] maps composition frames to source frames so
  /// [prepareClipFrames] can resolve the frame any composition frame needs.
  ///
  /// The clip is alive over `[windowStart, windowStart + windowLength)` in
  /// composition space at [compFps]; the trimmed source spans
  /// `[trimStartFrames, trimEndFrames)`. The source fps comes from the clip's
  /// already-probed metadata. Idempotent per source.
  void registerClipPlan({
    required MediaSource source,
    required int windowStart,
    required int windowLength,
    required int compFps,
    required int trimStartFrames,
    required int trimEndFrames,
  });

  /// Decodes (into the bounded window) the clip frames composition frame
  /// [compFrame] paints, loading them from the store and evicting the
  /// least-recently-used frames beyond the window. A no-op for a frame no
  /// registered clip is alive on. Must complete before the frame is pumped.
  Future<void> prepareClipFrames(int compFrame);
}
