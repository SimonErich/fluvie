import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/composition_fingerprint.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('outside-lib relative imports and parts invalidate cache without target edits', () async {
    final project = Directory.systemTemp.createTempSync('fluvie_fingerprint_relative_');
    addTearDown(() => project.deleteSync(recursive: true));
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: cat_video\n');
    final target = File(p.join(project.path, 'videos/cat.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync("import '../shared/helper.dart';\npart 'cat_part.dart';\n");
    final helper = File(p.join(project.path, 'shared/helper.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('const title = 1;\n');
    final part = File(p.join(project.path, 'videos/cat_part.dart'))
      ..writeAsStringSync("part of 'cat.dart';\nconst scene = 1;\n");
    final ignored = File(p.join(project.path, 'build/generated.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('const intermediate = 1;\n');

    Future<CompositionFingerprint> fingerprint() =>
        fingerprintComposition(project.path, extraFiles: [target.path]);
    final first = await fingerprint();
    final modified = helper.lastModifiedSync();
    helper
      ..writeAsStringSync('const title = 2;\n')
      ..setLastModifiedSync(modified);
    final helperChanged = await fingerprint();
    expect(
      helperChanged.digest,
      isNot(first.digest),
      reason: 'a helper-only edit changes rendered content',
    );
    part.writeAsStringSync("part of 'cat.dart';\nconst scene = 2;\n");
    final partChanged = await fingerprint();
    expect(
      partChanged.digest,
      isNot(helperChanged.digest),
      reason: 'part files also supply authored source',
    );
    ignored.writeAsStringSync('const intermediate = 2;\n');
    expect(
      (await fingerprint()).digest,
      partChanged.digest,
      reason: 'build outputs are not authored inputs',
    );
  });

  test('content changes invalidate cache even when size and timestamps stay equal', () async {
    final project = Directory.systemTemp.createTempSync('fluvie_fingerprint_');
    addTearDown(() => project.deleteSync(recursive: true));
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(
      'name: cat_video\nflutter:\n  fonts:\n    - family: Cat\n      fonts:\n        - asset: custom/cat.ttf\n',
    );
    final source = File(p.join(project.path, 'lib/video.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('const cat = 1;');
    final asset = File(p.join(project.path, 'assets/cat.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('cat');
    File(p.join(project.path, 'custom/cat.ttf'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final first = await fingerprintComposition(project.path);
    final modified = asset.lastModifiedSync();
    asset
      ..writeAsStringSync('dog')
      ..setLastModifiedSync(modified);
    final second = await fingerprintComposition(project.path);
    expect(second.digest, isNot(first.digest));
    expect(first.files.any((record) => record['path'] == 'project/custom/cat.ttf'), isTrue);
    source.writeAsStringSync('const cat = 2;');
    expect((await fingerprintComposition(project.path)).digest, isNot(second.digest));
    expect(
      (await fingerprintComposition(project.path)).digest,
      (await fingerprintComposition(project.path)).digest,
    );
  });

  test('transitive package source and raster/toolchain choices invalidate cache', () async {
    final fixture = Directory.systemTemp.createTempSync('fluvie_fingerprint_packages_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final project = Directory(p.join(fixture.path, 'project'))..createSync();
    final dependency = Directory(p.join(fixture.path, 'dependent'))..createSync();
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: cat_video\n');
    File(p.join(dependency.path, 'pubspec.yaml')).writeAsStringSync('name: cat_widgets\n');
    final imported = File(p.join(dependency.path, 'lib/scene.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('const value = 1;');
    File(p.join(project.path, '.dart_tool/package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'cat_widgets', 'rootUri': dependency.uri.toString(), 'packageUri': 'lib/'},
          ],
        }),
      );
    final first = await fingerprintComposition(
      project.path,
      context: {'toolchain': 'pinned', 'impeller': false},
    );
    imported.writeAsStringSync('const value = 2;');
    final second = await fingerprintComposition(
      project.path,
      context: {'toolchain': 'pinned', 'impeller': false},
    );
    expect(second.digest, isNot(first.digest));
    expect(
      (await fingerprintComposition(
        project.path,
        context: {'toolchain': 'pinned', 'impeller': true},
      )).digest,
      isNot(second.digest),
    );
  });
}
