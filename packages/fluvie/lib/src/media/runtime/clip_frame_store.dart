import 'dart:typed_data';

/// Backing store for a clip's extracted source frames (raw RGBA), kept off the
/// Dart heap so the decoded window can stay small.
///
/// The `dart:io` `MediaRepository` backs this with files in a temp directory;
/// a resolver with no store decodes every frame up front instead (the browser
/// path). Frames are addressed by an opaque per-clip [String] key plus the
/// source-frame index, and [dispose] releases the whole store.
abstract interface class ClipFrameStore {
  /// Writes the RGBA bytes of [frame] for the clip keyed by [clipKey].
  Future<void> put(String clipKey, int frame, Uint8List rgba);

  /// Reads the RGBA bytes of [frame] for [clipKey], or null when absent.
  Future<Uint8List?> get(String clipKey, int frame);

  /// Releases every stored frame.
  Future<void> dispose();
}
