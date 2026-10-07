import 'dart:io';

/// Desktop: dropped bytes become a real temp file, so the spec references
/// an honest `file` source the render pipeline can read.
Future<Map<String, Object?>> materializeDroppedMedia(String name, List<int> bytes) async {
  final dir = Directory('${Directory.systemTemp.path}/fluvie_media');
  await dir.create(recursive: true);
  final file = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}-$name');
  await file.writeAsBytes(bytes);
  return {'kind': 'file', 'value': file.path};
}
