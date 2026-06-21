/// The phase the on-device renderer is in, reported to an [OnDeviceProgress].
enum OnDeviceRenderPhase {
  /// Capturing frames off-screen through Fluvie's deterministic render loop.
  capturing,

  /// Encoding the captured frames to MP4 with the platform encoder.
  encoding,

  /// The MP4 is written and ready.
  complete,
}

/// A sink the on-device renderer calls as it moves through its phases.
///
/// Capture is one off-screen pass and encode is one native step, so this reports
/// phase transitions rather than per-frame counts. Purely observational: it
/// never affects the output bytes.
typedef OnDeviceProgress = void Function(OnDeviceRenderPhase phase);
