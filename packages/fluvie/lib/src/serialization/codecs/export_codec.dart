import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';

/// The JSON form of an [Export]: an object tagged by `mode`, carrying that
/// variant's field (`quality`, `fps`, or `format`).
Map<String, Object?> encodeExport(Export export) => switch (export.mode) {
  ExportMode.mp4 => {'mode': 'mp4', 'quality': encodeEnum(export.quality!)},
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
  switch (mode) {
    case ExportMode.mp4:
      final quality = raw['quality'];
      return Export.mp4(
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
