part of 'media_store_entry.dart';

MediaStoreEntry _mediaStoreEntryFromJson(Map<String, Object?> json) {
  final id = json['id'];
  final name = json['name'];
  final source = json['source'];
  if (id is! String || name is! String || source is! Map<String, Object?>) {
    throw const FormatException('A media entry needs id, name, and a {kind, value} source');
  }
  final kind = MediaStoreKind.values.asNameMap()[json['kind']];
  if (kind == null) {
    throw FormatException('Unknown media entry kind "${json['kind']}"');
  }
  final bytes = json['bytes'];
  final duration = json['duration'];
  final folder = json['folder'];
  int? whole(Object? value) => value is int && value >= 0 ? value : null;
  return MediaStoreEntry(
    id: id,
    name: name,
    kind: kind,
    source: Map<String, Object?>.of(source),
    sizeBytes: bytes is int ? bytes : null,
    duration: duration is String ? duration : null,
    folder: folder is String && folder.isNotEmpty ? folder : null,
    width: whole(json['width']),
    height: whole(json['height']),
    fps: json['fps'] is num && (json['fps']! as num).isFinite && (json['fps']! as num) > 0
        ? (json['fps']! as num).toDouble()
        : null,
    channels: whole(json['channels']),
    inFrames: whole(json['in']),
    outFrames: whole(json['out']),
  );
}

/// The seconds a spec time string names, for the forms the store writes
/// (`4s`, `120f` needs a rate and is refused here, `1500ms`).
double? _secondsOf(String spec) {
  if (spec.endsWith('ms')) {
    final value = double.tryParse(spec.substring(0, spec.length - 2));
    return value == null ? null : value / 1000;
  }
  if (spec.endsWith('s')) return double.tryParse(spec.substring(0, spec.length - 1));
  return null;
}
