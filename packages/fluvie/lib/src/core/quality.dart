/// The visual quality of an encoded export, from smallest file to
/// near-lossless.
///
/// Consumed by `Export.mp4(quality: Quality.high)` and by the render
/// configuration. This is pure data: how a level maps onto encoder settings
/// (CRF and friends) is a private detail of the encoder's argument builder,
/// so the mapping can improve without touching the public contract.
///
/// Names are serialized verbatim in render-config JSON — the enum order and
/// spelling are stable API.
enum Quality {
  /// Smallest files with visible compression — quick drafts and previews.
  low,

  /// A balanced size/quality trade-off for sharing rough cuts.
  medium,

  /// High visual quality, the default for published videos.
  high,

  /// Near-lossless output at the largest file size — archival masters.
  max,
}
