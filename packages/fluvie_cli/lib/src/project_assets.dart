import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// The asset directory a Fluvie project keeps its media in.
const String assetsDirName = 'assets';

/// Every directory under `<projectDir>/assets` that directly holds a file, as
/// pubspec-relative paths with a trailing slash, in stable sorted order.
///
/// Flutter enumerates an asset directory entry with a NON-recursive `listSync`,
/// so `assets/` bundles only the files sitting directly in it: a nested
/// `assets/images/logo.png` is silently missing at runtime with no build error.
/// Every directory that holds files therefore needs its own entry, which is what
/// this computes.
///
/// Directories holding only subdirectories are skipped (an entry for them would
/// bundle nothing), and so are Flutter's resolution variant directories
/// (`2.0x`, `3.0x`), whose files are picked up automatically alongside the base
/// asset. Returns empty when there is no `assets` directory.
List<String> assetDirEntries(String projectDir) {
  final root = Directory(p.join(projectDir, assetsDirName));
  if (!root.existsSync()) return const [];
  final entries = <String>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final dir = p.dirname(entity.path);
    if (_isVariantDir(dir)) continue;
    // Posix separators: a pubspec asset path is a URI-ish key, not a host path.
    final relative = p.url.joinAll(p.split(p.relative(dir, from: projectDir)));
    entries.add('$relative/');
  }
  final sorted = entries.toList()..sort();
  return sorted;
}

/// Whether [dir]'s last segment is a Flutter resolution variant (`2.0x`).
///
/// A variant's files are bundled through their base asset, so declaring the
/// variant directory would be redundant.
bool _isVariantDir(String dir) => RegExp(r'^\d+(\.\d+)?x$').hasMatch(p.basename(dir));

/// Rewrites `flutter: assets:` in [projectDir]'s pubspec to exactly the
/// directories that hold assets, returning whether the file changed.
///
/// The CLI owns this block: a project's asset tree is discovered per render, so
/// adding `assets/images/` never needs a pubspec edit and can never be silently
/// unbundled. Everything else in the pubspec is left untouched.
bool syncAssetsBlock(String projectDir) {
  final file = File(p.join(projectDir, 'pubspec.yaml'));
  if (!file.existsSync()) return false;
  final source = file.readAsStringSync();
  final entries = assetDirEntries(projectDir);
  final doc = loadYaml(source);
  final flutter = doc is YamlMap ? doc['flutter'] : null;
  final existing = flutter is YamlMap ? flutter['assets'] : null;
  final current = existing is YamlList ? existing.map((e) => '$e').toList() : const <String>[];
  if (_sameEntries(current, entries) && (existing != null || entries.isEmpty)) return false;

  final editor = YamlEditor(source);
  if (doc is! YamlMap || doc['flutter'] == null) {
    if (entries.isEmpty) return false;
    editor.update(['flutter'], {'assets': entries});
  } else if (entries.isEmpty) {
    if (existing == null) return false;
    editor.remove(['flutter', 'assets']);
  } else {
    editor.update(['flutter', 'assets'], entries);
  }
  file.writeAsStringSync(editor.toString());
  return true;
}

bool _sameEntries(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
