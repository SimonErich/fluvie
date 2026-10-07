import 'package:fluvie/src/core/encoder_options.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:meta/meta.dart';

/// The still-image format of an `Export.imageSequence`.
enum ImageFormat {
  /// Lossless PNG, one file per frame — the compositing-pipeline default.
  png,
}

/// What the render should produce: an MP4, a GIF, an image sequence,
/// or an alpha-capable overlay.
///
/// This is pure config data; the render pipeline dispatches on it at render.
/// A `Video(export: ...)` carries the value verbatim —
/// declaring it changes nothing about preview or capture. Exports are
/// value-equal within a variant, so configs can be compared and cached.
@immutable
final class Export {
  // coverage:ignore-start const ctor artifacts export_test pins each variant mode equality and toString The VM does not instrument the const literals
  const Export._(
    this.mode, {
    this.quality,
    this.gifFps,
    this.imageFormat,
    this.codec = ExportCodec.h264,
    this.crf,
    this.bitRate,
    this.preset = EncoderPreset.medium,
    this.pixelFormat = ExportPixelFormat.yuv420p,
  });

  /// An H.264 MP4 at [quality] — the default share-anywhere container.
  const Export.mp4({
    Quality this.quality = Quality.high,
    this.codec = ExportCodec.h264,
    this.crf,
    this.bitRate,
    this.preset = EncoderPreset.medium,
    this.pixelFormat = ExportPixelFormat.yuv420p,
  }) : assert(crf == null || (crf >= 0 && crf <= 51), 'CRF must be within 0..51'),
       assert(bitRate == null || bitRate > 0, 'Bitrate must be positive'),
       assert(crf == null || bitRate == null, 'Choose CRF or bitrate, not both'),
       mode = ExportMode.mp4,
       gifFps = null,
       imageFormat = null;

  /// An animated GIF sampled at [fps] (GIFs rarely need the full frame rate).
  const Export.gif({int fps = 15}) : this._(ExportMode.gif, gifFps: fps);

  /// One still per frame in [format] — for compositing pipelines.
  const Export.imageSequence({ImageFormat format = ImageFormat.png})
    : this._(ExportMode.imageSequence, imageFormat: format);

  /// An alpha-preserving overlay export (WebM/ProRes).
  const Export.transparent() : this._(ExportMode.transparent);
  // coverage:ignore-end

  /// The variant of this export, for the render pipeline's mode dispatch
  /// and the inspector. The factory used picks the mode:
  /// `Export.mp4()` is [ExportMode.mp4], and so on.
  final ExportMode mode;

  /// The encode quality of an [Export.mp4]; `null` on every other variant.
  final Quality? quality;

  /// MP4 codec; H.264 keeps the original default.
  final ExportCodec codec;

  /// Explicit constant-rate-factor quality, 0..51; mutually exclusive with bitrate.
  final int? crf;

  /// Target video bits per second; mutually exclusive with [crf].
  final int? bitRate;

  /// Software encoder speed/compression preset.
  final EncoderPreset preset;

  /// MP4 output pixel format.
  final ExportPixelFormat pixelFormat;

  /// Validates numeric choices in release builds before any encode or capture.
  void validate() {
    if (crf != null && (crf! < 0 || crf! > 51)) {
      throw ArgumentError.value(crf, 'crf', 'must be 0..51');
    }
    if (bitRate != null && bitRate! <= 0) {
      throw ArgumentError.value(bitRate, 'bitRate', 'must be positive');
    }
    if (crf != null && bitRate != null) throw ArgumentError('Choose CRF or bitrate, not both');
  }

  /// The sample rate of an [Export.gif]; `null` on every other variant.
  final int? gifFps;

  /// The frame format of an [Export.imageSequence]; `null` on every other
  /// variant.
  final ImageFormat? imageFormat;

  @override
  bool operator ==(Object other) =>
      other is Export &&
      other.mode == mode &&
      other.quality == quality &&
      other.gifFps == gifFps &&
      other.imageFormat == imageFormat &&
      other.codec == codec &&
      other.crf == crf &&
      other.bitRate == bitRate &&
      other.preset == preset &&
      other.pixelFormat == pixelFormat;

  @override
  int get hashCode => Object.hash(
    Export,
    mode,
    quality,
    gifFps,
    imageFormat,
    codec,
    crf,
    bitRate,
    preset,
    pixelFormat,
  );

  @override
  String toString() => switch (mode) {
    ExportMode.mp4 => 'Export.mp4(quality: $quality)',
    ExportMode.gif => 'Export.gif(fps: $gifFps)',
    ExportMode.imageSequence => 'Export.imageSequence(format: $imageFormat)',
    ExportMode.transparent => 'Export.transparent()',
  };
}

/// The four [Export] variants the render pipeline dispatches on.
/// Stable, public discriminator: the names are
/// the public surface the renderer and the inspector branch on.
enum ExportMode {
  /// An H.264 MP4 ([Export.mp4]).
  mp4,

  /// An animated GIF ([Export.gif]).
  gif,

  /// A lossless still per frame ([Export.imageSequence]).
  imageSequence,

  /// An alpha-preserving overlay ([Export.transparent]).
  transparent,
}
