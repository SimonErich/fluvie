import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/asset_catalog.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/image_evidence.dart';
import 'package:test/test.dart';

void main() {
  test('explicit image evidence is bounded, captioned and content checked', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_image_evidence_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final asset = File('${dir.path}/cat.mp4')..writeAsBytesSync([1, 2, 3]);
    final sheet = File('${dir.path}/sheet.png')..writeAsBytesSync([137, 80, 78, 71]);
    final catalog = File('${dir.path}/catalog.json')
      ..writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'kind': 'asset_catalog',
          'assets': [
            {
              'absolutePath': asset.path,
              'path': 'cat.mp4',
              'sha256': await assetContentHash(asset),
              'contactSheet': {
                'filePath': sheet.path,
                'sha256': await assetContentHash(sheet),
                'cells': [
                  {'timeSeconds': 1.25, 'row': 0, 'column': 0},
                ],
              },
            },
          ],
        }),
      );
    final images = await selectedImageEvidence(catalog.path);
    expect(images.single, containsPair('filePath', sheet.path));
    expect(images.single['caption'], contains('cat.mp4'));
    expect(images.single['caption'], contains('1.25'));
    await sheet.writeAsBytes([0]);
    await expectLater(selectedImageEvidence(catalog.path), throwsA(isA<CliFailure>()));
  });
}
