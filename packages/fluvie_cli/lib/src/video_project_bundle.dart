import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/composition_fingerprint.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/project_resources.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

part 'video_project_bundle_inputs.dart';
part 'video_project_bundle_dependencies.dart';
part 'video_project_bundle_unpack.dart';

/// Portable Dart video project, declared resources and dependency provenance.
///
/// Hosted packages remain pinned by the copied lock; local/Git dependencies are
/// vendored with relative overrides. Flutter/FFmpeg are runtime requirements,
/// recorded rather than embedded. Arbitrary runtime file and network inputs are
/// outside the bundle's declared-resource closure. Bundles contain executable
/// authored Dart; verification establishes integrity, not trust in that code.
final class VideoProjectBundle {
  VideoProjectBundle._();

  /// Creates a ZIP without changing source manifests or their resolution.
  /// Explicit [artifacts] may include finished exports and review directories.
  /// Limits bound the file count and uncompressed bytes during creation/replay.
  static Future<Map<String, Object?>> create({
    required FileTarget target,
    required String output,
    Map<String, Object?> settings = const {},
    List<String> artifacts = const [],
    int maxBytes = 2 * 1024 * 1024 * 1024,
    int maxFiles = 20000,
  }) async {
    if (!p.isWithin(p.absolute(target.projectDir), p.absolute(target.path))) {
      throw const CliFailure('The bundled entry must be inside its source project.');
    }
    final stage = await Directory.systemTemp.createTemp('fluvie_bundle_');
    final destination = File(p.absolute(output));
    Directory? publication;
    try {
      await destination.parent.create(recursive: true);
      publication = await destination.parent.createTemp('.fluvie-bundle-');
      final fingerprint = await fingerprintComposition(target.projectDir);
      final inputs = _BundleInputs(stage, maxBytes: maxBytes, maxFiles: maxFiles);
      await inputs.project(target.projectDir);
      await inputs.dependencies(target.projectDir);
      for (var i = 0; i < artifacts.length; i++) {
        final path = p.absolute(artifacts[i]);
        await inputs.tree(path, 'evidence/$i/${p.basename(path)}');
      }
      final files = stage.listSync(recursive: true, followLinks: false).whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      final records = <Map<String, Object?>>[];
      for (final file in files) {
        records.add({
          'path': p.relative(file.path, from: stage.path).replaceAll(p.separator, '/'),
          'byteLength': file.lengthSync(),
          'sha256': (await sha256.bind(file.openRead()).first).toString(),
        });
      }
      final manifest = <String, Object?>{
        'schemaVersion': 1,
        'entry':
            'project/${p.relative(target.path, from: target.projectDir).replaceAll(p.separator, '/')}',
        'entryFunction': target.entry,
        'settings': settings,
        'sourceRevision': fingerprint.digest,
        'sdk': fingerprint.sdk,
        'files': records,
        'scope':
            'Authored Dart, assets/, declared Flutter resources and resolved local/Git dependencies. '
            'Runtime file/network inputs require explicit materialization into the project.',
      };
      final manifestText = const JsonEncoder.withIndent('  ').convert(manifest);
      final finalBytes = records.fold<int>(
        0,
        (sum, record) => sum + (record['byteLength']! as int),
      );
      if (finalBytes + utf8.encode(manifestText).length > maxBytes) {
        throw const CliFailure('Video bundle exceeds its final byte budget.');
      }
      await atomicWrite(p.join(stage.path, 'bundle.json'), manifestText);
      if ((await fingerprintComposition(target.projectDir)).digest != fingerprint.digest) {
        throw const CliFailure(
          'Source inputs changed while bundling. Retry against a stable revision.',
        );
      }
      final zip = ZipFileEncoder();
      final pending = p.join(publication.path, 'bundle.zip');
      zip.create(pending);
      try {
        for (final file in [...files, File(p.join(stage.path, 'bundle.json'))]) {
          await zip.addFile(
            file,
            p.relative(file.path, from: stage.path).replaceAll(p.separator, '/'),
          );
        }
      } finally {
        await zip.close();
      }
      await File(pending).rename(destination.path);
      return manifest;
    } finally {
      await stage.delete(recursive: true);
      await publication?.delete(recursive: true);
    }
  }

  /// Verifies a bundle in an owned temporary directory without executing Dart.
  static Future<Map<String, Object?>> inspect(
    String zip, {
    int maxBytes = 2 * 1024 * 1024 * 1024,
  }) async {
    final temporary = await Directory.systemTemp.createTemp('fluvie_bundle_inspect_');
    try {
      final result = await unpack(zip, p.join(temporary.path, 'project'), maxBytes: maxBytes);
      return result..remove('directory');
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  /// Validates paths, sizes, entry and content hashes before publishing a new
  /// destination. Existing destinations are never overwritten or merged.
  static Future<Map<String, Object?>> unpack(
    String zip,
    String destination, {
    int maxBytes = 2 * 1024 * 1024 * 1024,
    int maxFiles = 20000,
  }) => _unpackBundle(zip, destination, maxBytes: maxBytes, maxFiles: maxFiles);
}
