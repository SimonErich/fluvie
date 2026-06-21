/// The hardware video codec the on-device encoder targets.
///
/// Both are encoded by the platform's own hardware encoder (`MediaCodec` on
/// Android, VideoToolbox on iOS), so neither bundles a codec nor pulls in an
/// FFmpeg dependency. [h264] is the most compatible; [hevc] produces smaller
/// files at the same quality where the device supports it.
enum MobileVideoCodec {
  /// H.264 / AVC. The most broadly compatible choice, and the default.
  h264,

  /// H.265 / HEVC. Smaller files at the same quality on supporting devices.
  hevc;

  /// The stable wire name sent to the platform encoder (`h264` or `hevc`).
  String get wireName => switch (this) {
    MobileVideoCodec.h264 => 'h264',
    MobileVideoCodec.hevc => 'hevc',
  };
}
