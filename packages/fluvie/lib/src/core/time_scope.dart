/// @docImport 'package:fluvie/src/core/time.dart';
library;

/// The resolution context a [Time] resolves against.
///
/// A scope pins down the two facts frame math needs — the frame rate and the
/// length of the enclosing window — so a symbolic [Time] can become a concrete
/// frame count via [Time.resolveFrames]. Scopes nest: the video, each scene,
/// and any element with its own window all define one.
///
/// `core` only declares this contract; the engine provides the concrete scope
/// when the timing layer lands. Call sites never construct one — they hand
/// symbolic [Time] values to Fluvie and let it resolve them.
abstract interface class TimeScope {
  /// Frames per second of the enclosing render.
  int get fps;

  /// The absolute video frame at which this window begins.
  ///
  /// `0` at the root; a scene reports the running offset of the scenes before
  /// it; an element window reports its place within the video. [Time]
  /// resolution never reads this — it positions resolved spans absolutely.
  int get startFrame;

  /// Total length of the enclosing window, in frames.
  int get durationFrames;

  /// The enclosing scope, or `null` at the root (the video itself).
  ///
  /// Scopes chain video → scene → element window; the chain is diagnostic
  /// and structural — resolution always uses the *nearest* scope.
  TimeScope? get parent;
}
