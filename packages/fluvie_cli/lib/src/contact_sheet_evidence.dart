import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/asset_catalog.dart';
import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:fluvie_media/native.dart';
import 'package:path/path.dart' as p;

/// A native picture boundary injectable independently of process provisioning.
typedef ContactSheetCapture =
    Future<MediaContactSheet> Function(Uri source, {required String outputPath});

/// Reuses local evidence only when source, layout, toolchain, and PNG content
/// identities match. Corrupt cache metadata is regenerated without user repair.
Future<Map<String, Object?>> cachedContactSheet(
  File source, {
  required String sourceHash,
  required String outputDirectory,
  required Map<String, Object?> toolchain,
  required ContactSheetCapture capture,
}) async {
  final identity = {
    'version': 1,
    'sourceHash': sourceHash,
    'toolchain': toolchain,
    'layout': {'columns': 3, 'samples': 6, 'cellWidth': 320, 'cellHeight': 180},
  };
  final key = sha256.convert(utf8.encode(jsonEncode(identity))).toString();
  final path = p.join(outputDirectory, '$key.png');
  final metadata = File('$path.json');
  if (metadata.existsSync() && File(path).existsSync()) {
    try {
      final cached = jsonDecode(await metadata.readAsString());
      if (cached is Map<String, Object?> &&
          cached['cacheKey'] == key &&
          cached['sha256'] == await assetContentHash(File(path))) {
        return cached;
      }
    } on FormatException {
      // These generated artifacts are disposable; a new sheet repairs them.
    }
  }
  final sheet = await capture(source.uri, outputPath: path);
  final result = <String, Object?>{
    ...sheet.toJson(),
    'cacheKey': key,
    'sha256': await assetContentHash(File(sheet.filePath)),
    'sourceHash': sourceHash,
    'certainty': 'observed',
    'provenance': {
      'kind': 'ffmpeg_contact_sheet',
      'sourcePath': source.absolute.path,
      'toolchain': toolchain,
    },
  };
  await atomicWrite(metadata.path, jsonEncode(result));
  return result;
}
