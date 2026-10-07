/// The MP4 video codec. Values map to fixed encoder names, never user strings.
enum ExportCodec {
  /// H.264/AVC, broadly supported by players.
  h264,

  /// H.265/HEVC, higher compression where the decoder supports it.
  h265,
}

/// Closed software-encoder speed/compression choices.
enum EncoderPreset {
  /// Fastest encoding, largest output at equal quality.
  ultrafast,

  /// Very low encoding cost.
  superfast,

  /// Fast encoding for previews.
  veryfast,

  /// Faster than the standard compromise.
  faster,

  /// Prefer shorter encode time.
  fast,

  /// Default speed/compression compromise.
  medium,

  /// Prefer stronger compression.
  slow,

  /// More compression effort.
  slower,

  /// Maximum supported compression effort.
  veryslow,
}

/// Closed output pixel formats supported by the software MP4 path.
enum ExportPixelFormat {
  /// 8-bit 4:2:0, compatible with common players and hardware encoders.
  yuv420p,

  /// 10-bit 4:2:0, for a compatible software encoder and player.
  yuv420p10le,

  /// 8-bit 4:4:4, retains chroma resolution for graphics.
  yuv444p,
}
