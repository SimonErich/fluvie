import 'dart:typed_data';

/// A growable byte sink the capture loop appends raw frame bytes to.
///
/// The file-backed sandbox writes through to disk; the in-memory sandbox
/// accumulates into a buffer. The frame loop only ever calls [add] then [close],
/// so the two backends are interchangeable.
abstract interface class CaptureSink {
  /// Appends [bytes] to the sink.
  void add(Uint8List bytes);

  /// Flushes and closes the sink.
  Future<void> close();
}

/// Storage for one render: the frames file, the manifest, materialized encoder
/// inputs, and the encoded output.
///
/// Two backends implement it — a file-backed sandbox under a real directory
/// (desktop/mobile, byte-identical to writing files directly) and an in-memory
/// sandbox (web, where the browser has no file system). The capture loop and the
/// `FfmpegRunner`s talk only to this interface, so the same deterministic
/// pipeline runs on every platform.
abstract interface class RenderSandbox {
  /// The real directory path a process-based encoder runs in, or `null` for an
  /// in-memory sandbox (a process encoder is never selected there).
  String? get directoryPath;

  /// Prepares the sandbox for writing (creates the directory for a file-backed
  /// sandbox; a no-op in memory).
  Future<void> create();

  /// Opens [name] for appending raw frame bytes.
  CaptureSink openFrames(String name);

  /// Writes [content] to [name] as UTF-8 text (the manifest).
  Future<void> writeText(String name, String content);

  /// Writes [bytes] to [name] (a materialized encoder input, or an output).
  Future<void> writeBytes(String name, Uint8List bytes);

  /// Reads [name] back as bytes.
  Future<Uint8List> readBytes(String name);
}
