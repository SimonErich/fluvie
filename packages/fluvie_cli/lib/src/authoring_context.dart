import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/asset_catalog.dart';
import 'package:fluvie_cli/src/asset_inventory.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_media/native.dart';
import 'package:path/path.dart' as p;

/// Resolves authoring inputs against the selected source project. Absolute
/// paths retain their location, allowing explicitly selected external inputs.
String resolveAuthoringInputPath(String projectDir, String input) =>
    p.normalize(p.isAbsolute(input) ? input : p.join(p.absolute(projectDir), input));

/// Bounded factual assets plus explicitly selected prose for built-in authoring.
/// No visual interpretation or implicit reading of story files happens here.
Future<String> buildAuthoringContext({
  required String projectDir,
  FfmpegToolchain? toolchain,
  String? context,
  List<String> contextFiles = const [],
  String? assetsDir,
  String? catalogPath,
}) async {
  const byteLimit = 65536;
  const textLimit = 8192;
  final root = Directory(resolveAuthoringInputPath(projectDir, assetsDir ?? 'assets'));
  final files = root.existsSync() ? inventoryFiles(root) : <File>[];
  final selected =
      contextFiles.map((input) => resolveAuthoringInputPath(projectDir, input)).toSet().toList()
        ..sort();
  if (selected.length > 4) {
    throw const CliFailure('Select at most four --context-file inputs (8192 bytes each).');
  }
  final notes = <Map<String, Object?>>[];
  final catalog = catalogPath == null
      ? null
      : await readAssetCatalog(
          resolveAuthoringInputPath(projectDir, catalogPath),
        );
  final evidence = <Map<String, Object?>>[];
  if (catalog != null) {
    for (final asset in (catalog['assets']! as List<Object?>).cast<Map<String, Object?>>()) {
      final record = {
        'path': asset['path'],
        'assetKey': asset['assetKey'],
        'absolutePath': asset['absolutePath'],
        'sha256': asset['sha256'],
        'observations': asset['observations'],
        'contactSheet': asset['contactSheet'],
      };
      if (utf8.encode(jsonEncode([...evidence, record])).length > 24576) break;
      evidence.add(record);
    }
  }
  if (context != null && context.isNotEmpty) {
    final bytes = utf8.encode(context);
    notes.add({
      'text': utf8.decode(bytes.take(textLimit).toList(), allowMalformed: true),
      'truncated': bytes.length > textLimit,
    });
  }
  for (final path in selected) {
    final file = File(path);
    if (!file.existsSync()) throw CliFailure('Context file not found: "$path".');
    final handle = await file.open();
    try {
      final bytes = await handle.read(textLimit + 1);
      notes.add({
        'path': p.absolute(path),
        'text': utf8.decode(bytes.take(textLimit).toList(), allowMalformed: true),
        'truncated': bytes.length > textLimit,
      });
    } finally {
      await handle.close();
    }
  }
  final tools = toolchain == null
      ? null
      : FfmpegMediaTools(ffmpegPath: toolchain.ffmpegPath, ffprobePath: toolchain.ffprobePath);
  final facts = <Map<String, Object?>>[];
  try {
    for (final file in files.take(100)) {
      Map<String, Object?> fact;
      try {
        fact = await inspectAsset(
          file,
          root: root.path,
          project: projectDir,
          probe: tools?.probeReport,
          textLimit: 0,
        );
      } on Object catch (error) {
        fact = await inspectAsset(file, root: root.path, project: projectDir, textLimit: 0);
        fact['metadataError'] = '$error';
      }
      fact.removeWhere(
        (key, _) =>
            {'modifiedUtc', 'probe', 'text'}.contains(key) ||
            (key == 'absolutePath' && fact['assetKey'] is String),
      );
      final candidate = {
        'schemaVersion': 1,
        'assets': [...facts, fact],
        'notes': notes,
        'evidence': evidence,
      };
      if (utf8.encode(jsonEncode(candidate)).length > byteLimit - 1024) break;
      facts.add(fact);
    }
  } finally {
    tools?.close();
  }
  return 'Use these factual local inputs. Asset names identify files; do not infer visual content from filenames. '
      'Explicitly supplied notes and content-bound evidence describe the story; preserve their certainty and provenance. '
      'A contact-sheet receipt describes timestamps, not depicted content. Only claim visual inspection when image evidence is explicitly attached. '
      'Use exact assetKey values for assets or the explicit absolutePath for external file sources; '
      'preserve probed media timing and report omitted/unavailable facts.\n'
      '${jsonEncode({
        'schemaVersion': 1,
        'assets': facts,
        'totalAssets': files.length,
        'omittedAssets': files.length - facts.length,
        'notes': notes,
        'evidence': evidence,
        'limits': {'assets': 100, 'textBytesPerInput': textLimit, 'totalBytes': byteLimit},
      })}';
}
