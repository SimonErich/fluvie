import 'package:fluvie/src/core/encoder_options.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';

/// The JSON form of an [Export]: an object tagged by `mode`, carrying that
/// variant's field (`quality`, `fps`, or `format`).
Map<String, Object?> encodeExport(Export export) => switch (export.mode) {
  ExportMode.mp4 => {
    'mode': 'mp4',
    'quality': encodeEnum(export.quality!),
    if (export.codec != ExportCodec.h264) 'codec': export.codec.name,
    if (export.crf != null) 'crf': export.crf,
    if (export.bitRate != null) 'bitRate': export.bitRate,
    if (export.preset != EncoderPreset.medium) 'preset': export.preset.name,
    if (export.pixelFormat != ExportPixelFormat.yuv420p) 'pixelFormat': export.pixelFormat.name,
  },
  ExportMode.gif => {'mode': 'gif', 'fps': export.gifFps},
  ExportMode.imageSequence => {'mode': 'imageSequence', 'format': encodeEnum(export.imageFormat!)},
  ExportMode.transparent => {'mode': 'transparent'},
};

/// Reads an [Export] from an object in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) for a non-object or an unknown
/// mode; absent variant fields fall back to the factory defaults.
Export decodeExport(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected an export object', path: path);
  }
  final mode = decodeEnum(ExportMode.values, raw['mode'], 'export mode', path: [...path, 'mode']);
  final allowed = switch (mode) {
    ExportMode.mp4 => const {'mode', 'quality', 'codec', 'crf', 'bitRate', 'preset', 'pixelFormat'},
    ExportMode.gif => const {'mode', 'fps'},
    ExportMode.imageSequence => const {'mode', 'format'},
    ExportMode.transparent => const {'mode'},
  };
  for (final key in raw.keys) {
    if (!allowed.contains(key)) {
      throw FluvieSpecError(
        'Unknown export property "$key" for ${mode.name}',
        path: [...path, key],
      );
    }
  }
  switch (mode) {
    case ExportMode.mp4:
      final quality = raw['quality'];
      final crf = raw['crf'];
      final bitRate = raw['bitRate'];
      if (crf != null && (crf is! int || crf < 0 || crf > 51)) {
        throw FluvieSpecError('CRF must be an integer within 0..51', path: [...path, 'crf']);
      }
      if (bitRate != null && (bitRate is! int || bitRate <= 0)) {
        throw FluvieSpecError(
          'Bitrate must be a positive integer in bits per second',
          path: [...path, 'bitRate'],
        );
      }
      if (crf != null && bitRate != null) {
        throw FluvieSpecError('Choose CRF or bitrate, not both', path: path);
      }
      return Export.mp4(
        codec: raw['codec'] == null
            ? ExportCodec.h264
            : decodeEnum(ExportCodec.values, raw['codec'], 'codec', path: [...path, 'codec']),
        crf: crf as int?,
        bitRate: bitRate as int?,
        preset: raw['preset'] == null
            ? EncoderPreset.medium
            : decodeEnum(
                EncoderPreset.values,
                raw['preset'],
                'encoder preset',
                path: [...path, 'preset'],
              ),
        pixelFormat: raw['pixelFormat'] == null
            ? ExportPixelFormat.yuv420p
            : decodeEnum(
                ExportPixelFormat.values,
                raw['pixelFormat'],
                'pixel format',
                path: [...path, 'pixelFormat'],
              ),
        quality: quality == null
            ? Quality.high
            : decodeEnum(Quality.values, quality, 'quality', path: [...path, 'quality']),
      );
    case ExportMode.gif:
      final fps = raw['fps'];
      return Export.gif(fps: fps is int ? fps : 15);
    case ExportMode.imageSequence:
      final format = raw['format'];
      return Export.imageSequence(
        format: format == null
            ? ImageFormat.png
            : decodeEnum(ImageFormat.values, format, 'image format', path: [...path, 'format']),
      );
    case ExportMode.transparent:
      return const Export.transparent();
  }
}
