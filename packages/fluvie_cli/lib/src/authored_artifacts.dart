import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/codegen.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:path/path.dart' as p;

/// Validated readable code and its reproducible authoring document.
final class AuthoredArtifacts {
  const AuthoredArtifacts({
    required this.specPath,
    required this.dartPath,
    required this.sourceHash,
  });
  final String specPath;
  final String dartPath;
  final String sourceHash;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'event': 'authored',
    'specPath': specPath,
    'dartPath': dartPath,
    'sourceHash': sourceHash,
    'previewCommand': 'fluvie preview ${jsonEncode(dartPath)}',
  };

  /// Formats before publishing either artifact. Default code paths preserve
  /// existing handwritten files by choosing the next available numbered name.
  static Future<AuthoredArtifacts> publish({
    required String pendingSpec,
    required String specPath,
    required String projectDir,
    String? dartPath,
    String name = 'generated_video',
  }) async {
    final text = await File(pendingSpec).readAsString();
    final json = jsonDecode(text);
    if (json is! Map<String, Object?>) throw const CliFailure('Expected an authored spec object.');
    final source = printVideoSpecJson(json);
    var output = dartPath ?? p.join(projectDir, 'lib', '$name.dart');
    if (dartPath == null) {
      var index = 2;
      while (File(output).existsSync()) {
        output = p.join(projectDir, 'lib', '${name}_${index++}.dart');
      }
    }
    await atomicWrite(output, source);
    await atomicWrite(specPath, text);
    return AuthoredArtifacts(
      specPath: p.absolute(specPath),
      dartPath: p.absolute(output),
      sourceHash: sha256.convert(utf8.encode(source)).toString(),
    );
  }
}

/// Publishes a complete file using a same-directory atomic rename.
Future<void> atomicWrite(String path, String text) async {
  final target = File(path);
  await target.parent.create(recursive: true);
  final directory = await target.parent.createTemp('.fluvie-publish-');
  try {
    final pending = File(p.join(directory.path, p.basename(path)));
    await pending.writeAsString(text, flush: true);
    await pending.rename(target.absolute.path);
  } finally {
    await directory.delete(recursive: true);
  }
}
