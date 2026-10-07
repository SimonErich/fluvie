import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/asset_catalog.dart';
import 'package:fluvie_cli/src/cli_failure.dart';

/// Selects up to four content-verified contact sheets for an explicit provider
/// upload. Each image is bounded to 4 MiB and carries exact asset/time records.
Future<List<Map<String, Object?>>> selectedImageEvidence(String catalogPath) async {
  final catalog = await readAssetCatalog(catalogPath);
  final images = <Map<String, Object?>>[];
  for (final asset in (catalog['assets']! as List<Object?>).cast<Map<String, Object?>>()) {
    final sheet = asset['contactSheet'];
    if (sheet is! Map<String, Object?>) continue;
    final path = sheet['filePath']! as String;
    if (await File(path).length() > 4 * 1024 * 1024) {
      throw CliFailure('Image evidence exceeds 4 MiB: "$path".');
    }
    images.add({
      'filePath': path,
      'sha256': sheet['sha256'],
      'mediaType': 'image/png',
      'caption':
          'Contact sheet for ${asset['assetKey'] ?? asset['path']}. '
          'Source SHA: ${asset['sha256']}. Cells: ${jsonEncode(sheet['cells'])}. '
          'Describe only visible content; distinguish observations from uncertain interpretations.',
    });
    if (images.length == 4) break;
  }
  if (images.isEmpty) {
    throw const CliFailure(
      'No contact sheets in the selected catalog. Run assets --contact-sheets first.',
    );
  }
  return images;
}
