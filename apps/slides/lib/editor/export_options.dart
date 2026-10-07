import 'package:flutter/foundation.dart' show immutable;
import 'package:fluvie/fluvie.dart'
    show EncoderPreset, Export, ExportCodec, ExportPixelFormat, Quality, VideoSpec;

/// What one video export runs at: its canvas long edge and encode quality.
///
/// These are an **override** for one run, never a second source of truth.
/// [ExportOptions.forSpec] reads the deck's own values, which is what the
/// dialog opens on; an author who changes them and does not persist them
/// exports once at the new settings and leaves the document alone.
///
/// Resolution is a long edge rather than a width and height on purpose. Both
/// render arms derive their canvas as `aspectForSize(...).sizeFor(longEdge)`,
/// which forces the deck's own aspect family, so an arbitrary width and height
/// could not be honoured and offering one would be a lie.
///
/// **Frame rate is deliberately not here.** A deck's fps is what its timeline
/// is measured in: every scene duration, window and animation span resolves
/// against it. Capturing at a different rate would pump a frame count the
/// composition's own timeline does not have, so the render would either run
/// past the end holding its last frame or stop short. Changing the rate is
/// therefore a change to the document, made through an undoable command that
/// moves the render digest — not a per-run override.
@immutable
final class ExportOptions {
  /// Creates the options one render runs at.
  const ExportOptions({
    required this.longEdge,
    this.quality = Quality.high,
    this.codec = ExportCodec.h264,
    this.crf,
    this.bitRate,
    this.preset = EncoderPreset.medium,
    this.pixelFormat = ExportPixelFormat.yuv420p,
  });

  /// The options a deck exports at when nothing is overridden: its own canvas
  /// long edge, at the pipeline's default quality.
  factory ExportOptions.forSpec(VideoSpec spec) => ExportOptions(
    longEdge: spec.size.width > spec.size.height ? spec.size.width : spec.size.height,
    quality: spec.export?.quality ?? Quality.high,
    codec: spec.export?.codec ?? ExportCodec.h264,
    crf: spec.export?.crf,
    bitRate: spec.export?.bitRate,
    preset: spec.export?.preset ?? EncoderPreset.medium,
    pixelFormat: spec.export?.pixelFormat ?? ExportPixelFormat.yuv420p,
  );

  /// The canvas long edge in pixels; the short edge follows the deck's aspect.
  final int longEdge;

  /// The encode quality, mapped to a CRF by the argument builder.
  final Quality quality;

  /// Codec selected for this delivery.
  final ExportCodec codec;

  /// Optional explicit CRF (exclusive with bitrate).
  final int? crf;

  /// Optional target video bits per second (exclusive with CRF).
  final int? bitRate;

  /// Software encoder speed/compression choice.
  final EncoderPreset preset;

  /// Output chroma sampling and bit depth.
  final ExportPixelFormat pixelFormat;

  /// The typed export settings for this run.
  Export get export => Export.mp4(
    quality: quality,
    codec: codec,
    crf: crf,
    bitRate: bitRate,
    preset: preset,
    pixelFormat: pixelFormat,
  );

  /// Applies only to the render snapshot; the editor document stays unchanged.
  VideoSpec applyTo(VideoSpec spec) => VideoSpec.fromJson({
    ...spec.toJson(),
    'export': {
      'mode': 'mp4',
      'quality': quality.name,
      if (codec != ExportCodec.h264) 'codec': codec.name,
      if (crf != null) 'crf': crf,
      if (bitRate != null) 'bitRate': bitRate,
      if (preset != EncoderPreset.medium) 'preset': preset.name,
      if (pixelFormat != ExportPixelFormat.yuv420p) 'pixelFormat': pixelFormat.name,
    },
  });

  /// A copy with the named fields replaced.
  ExportOptions copyWith({
    int? longEdge,
    Quality? quality,
    ExportCodec? codec,
    int? crf,
    int? bitRate,
    EncoderPreset? preset,
    ExportPixelFormat? pixelFormat,
    bool clearRateControl = false,
  }) => ExportOptions(
    longEdge: longEdge ?? this.longEdge,
    quality: quality ?? this.quality,
    codec: codec ?? this.codec,
    crf: clearRateControl || bitRate != null ? null : crf ?? this.crf,
    bitRate: clearRateControl || crf != null ? null : bitRate ?? this.bitRate,
    preset: preset ?? this.preset,
    pixelFormat: pixelFormat ?? this.pixelFormat,
  );

  @override
  bool operator ==(Object other) =>
      other is ExportOptions &&
      other.longEdge == longEdge &&
      other.quality == quality &&
      other.codec == codec &&
      other.crf == crf &&
      other.bitRate == bitRate &&
      other.preset == preset &&
      other.pixelFormat == pixelFormat;

  @override
  int get hashCode =>
      Object.hash(ExportOptions, longEdge, quality, codec, crf, bitRate, preset, pixelFormat);

  @override
  String toString() => 'ExportOptions(longEdge: $longEdge, quality: ${quality.name})';
}
