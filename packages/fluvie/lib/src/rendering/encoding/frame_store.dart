import 'dart:typed_data';

/// A content-addressed store of captured frame bytes, keyed by render digest and
/// frame index, so an unchanged render replays instead of re-capturing.
///
/// Kept free of `dart:io` so the capture loop runs on every platform: the disk
/// `FrameCache` adapts to it on desktop and mobile (via `FrameCacheStore`); the
/// web path simply passes none.
abstract interface class FrameStore {
  /// The cached bytes for [frameIndex] of [digest], or `null` on a miss.
  Future<Uint8List?> lookup(String digest, int frameIndex);

  /// Stores [bytes] for [frameIndex] of [digest].
  Future<void> store(String digest, int frameIndex, Uint8List bytes);
}
