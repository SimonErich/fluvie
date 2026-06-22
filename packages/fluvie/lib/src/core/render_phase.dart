/// The stage a render is in: capturing frames, encoding them, or finished.
///
/// Reported through `RenderProgress` and stamped onto a `FluvieRenderException`
/// so a failure says whether capture or encode broke.
enum RenderPhase {
  /// The deterministic frame-capture loop is running.
  capturing,

  /// The captured frames are being encoded into the output.
  encoding,

  /// The render finished and the output is ready.
  complete,
}
