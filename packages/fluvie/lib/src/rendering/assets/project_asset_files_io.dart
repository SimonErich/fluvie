import 'dart:io';
import 'dart:typed_data';

/// The discovered keys and their byte reader.
typedef ProjectAssetFiles = ({List<String> keys, Future<ByteData> Function(String) read});

/// Inventories dropped project assets without editing Flutter declarations.
Future<ProjectAssetFiles> discoverProjectAssets(String projectDir) async {
  final project = Directory(projectDir).absolute;
  final directory = Directory('${project.path}/assets');
  final keys = <String>[];
  if (directory.existsSync()) {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        keys.add(entity.path.substring(project.path.length + 1).replaceAll(r'\', '/'));
      }
    }
  }
  keys.sort();
  return (
    keys: keys,
    read: (String key) async =>
        ByteData.sublistView(await File('${project.path}/$key').readAsBytes()),
  );
}
