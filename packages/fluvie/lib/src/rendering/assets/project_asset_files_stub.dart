import 'dart:typed_data';

/// The discovered keys and their byte reader.
typedef ProjectAssetFiles = ({List<String> keys, Future<ByteData> Function(String) read});

/// Browser hosts provide their inventory and reader directly.
Future<ProjectAssetFiles> discoverProjectAssets(String projectDir) => throw UnsupportedError(
  'On web, construct ProjectAssetBundle with an inventory and asset reader.',
);
