import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/asset_inventory.dart';
import 'package:fluvie_cli/src/asset_observations.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:path/path.dart' as p;

/// Generates local visual evidence; interpretation is supplied explicitly by
/// the user or by a separately opted-in provider request.
typedef AssetSheetBuilder = Future<Map<String, Object?>> Function(File file, String sourceHash);

/// Builds a reusable factual catalog with content-bound semantic observations.
/// Nothing is inferred from filenames and no provider is called here.
Future<Map<String, Object?>> buildAssetCatalog({
  required Directory root,
  required String project,
  AssetProbe? probe,
  String? evidenceFile,
  List<String> transcripts = const [],
  AssetSheetBuilder? sheetBuilder,
  Set<String> excludedFiles = const {},
  Set<String> excludedDirectories = const {},
}) async {
  final files =
      inventoryFiles(
            root,
          )
          .where(
            (file) =>
                !excludedFiles.contains(file.absolute.path) &&
                !excludedDirectories.any(
                  (directory) => p.isWithin(p.absolute(directory), file.absolute.path),
                ),
          )
          .toList();
  final observations = await readAssetObservations(
    root: root.absolute.path,
    assetPaths: files
        .map((file) => p.url.joinAll(p.split(p.relative(file.path, from: root.path))))
        .toSet(),
    evidenceFile: evidenceFile,
    transcripts: transcripts,
  );
  final assets = <Map<String, Object?>>[];
  for (final file in files) {
    final hash = await assetContentHash(file);
    final facts = await inspectAsset(
      file,
      root: root.path,
      project: project,
      probe: probe,
      textLimit: 0,
    );
    facts.remove('text');
    final path = facts['path']! as String;
    final sheet = sheetBuilder != null && {'video', 'image'}.contains(facts['kind'])
        ? await sheetBuilder(file, hash)
        : null;
    if (sheet != null && await assetContentHash(file) != hash) {
      throw CliFailure('Asset changed while preparing its visual evidence: "$path".');
    }
    assets.add({
      ...facts,
      'sha256': hash,
      'observations': observations[path] ?? <Object?>[],
      'contactSheet': sheet,
    });
  }
  return {
    'schemaVersion': 1,
    'kind': 'asset_catalog',
    'root': root.absolute.path,
    'project': p.absolute(project),
    'assets': assets,
  };
}

/// Streaming content identity, independent of file modification timestamps.
Future<String> assetContentHash(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// Loads selected evidence only when its source and image identities still
/// match. A stale catalog must be regenerated, rather than silently trusted.
Future<Map<String, Object?>> readAssetCatalog(String path) async {
  final file = File(path);
  if (await file.length() > 4 * 1024 * 1024) throw const CliFailure('Asset catalog exceeds 4 MiB.');
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, Object?> ||
      decoded['schemaVersion'] != 1 ||
      decoded['kind'] != 'asset_catalog' ||
      decoded['assets'] is! List<Object?>) {
    throw const CliFailure(
      'Unsupported asset catalog. Rebuild it with fluvie assets --catalog-out.',
    );
  }
  final assets = decoded['assets']! as List<Object?>;
  if (assets.length > 1000) throw const CliFailure('Asset catalog exceeds 1000 entries.');
  for (final asset in assets) {
    if (asset is! Map<String, Object?> ||
        asset['absolutePath'] is! String ||
        asset['sha256'] is! String) {
      throw const CliFailure('Catalog entries must include absolutePath and sha256.');
    }
    await _verifyIdentity(asset['absolutePath']! as String, asset['sha256']! as String);
    final sheet = asset['contactSheet'];
    if (sheet != null) {
      if (sheet is! Map<String, Object?> ||
          sheet['filePath'] is! String ||
          sheet['sha256'] is! String) {
        throw const CliFailure('Contact sheet identity is incomplete.');
      }
      await _verifyIdentity(sheet['filePath']! as String, sheet['sha256']! as String);
    }
  }
  return decoded;
}

Future<void> _verifyIdentity(String path, String expected) async {
  final file = File(path);
  if (!file.existsSync() || await assetContentHash(file) != expected) {
    throw CliFailure(
      'Catalog evidence is stale for "$path". Rebuild with fluvie assets --catalog-out.',
    );
  }
}
