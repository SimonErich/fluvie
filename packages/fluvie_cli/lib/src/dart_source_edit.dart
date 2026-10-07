import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_validate/source_edits.dart';
import 'package:path/path.dart' as p;

/// Applies the shared pure-Dart patch rules, exposing CLI failure diagnostics.
String applyDartEdits(String source, String reply) {
  try {
    return applyDartSourceEdits(source, reply);
  } on SourceEditException catch (error) {
    throw CliFailure(error.message);
  }
}

/// Identity and recovery artifact for a validated, published source edit.
typedef DartEditResult = ({String dartPath, String backupPath, String sourceHash});

/// Requests replacements, validates a temporary sibling in the same import
/// context, and publishes only when the original content still has its hash.
/// Validation failures leave the source and previous backup untouched.
Future<DartEditResult> editDartSource({
  required File file,
  required Future<String> Function(String source) requestEdits,
  required Future<void> Function(File pending) validate,
  Future<String> Function(String source, String feedback)? repairEdits,
  int maxRepairs = 2,
}) async {
  if (maxRepairs < 0 || maxRepairs > 3) throw ArgumentError('Use 0..3 compiler repairs.');
  if (FileSystemEntity.typeSync(file.path, followLinks: false) != FileSystemEntityType.file) {
    throw const CliFailure('Dart editing requires a regular source file, not a symbolic link.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.length > 256 * 1024) {
    throw const CliFailure('Dart editing accepts source files up to 256 KiB.');
  }
  final hash = sha256.convert(bytes);
  var source = utf8.decode(bytes);
  if (bytes.length >= 3 && bytes[0] == 239 && bytes[1] == 187 && bytes[2] == 191) {
    source = '\uFEFF$source';
  }
  var replacement = applyDartEdits(source, await requestEdits(source));
  final directory = await file.parent.createTemp('_fluvie_edit_');
  // The source is a sibling, rather than inside the temporary directory, so
  // authored relative imports and parts resolve exactly as before publication.
  final pending = File(p.join(file.parent.path, '${p.basename(directory.path)}.dart'));
  final backup = File('${file.path}.fluvie.bak');
  try {
    for (var attempt = 0; ; attempt++) {
      await pending.writeAsString(replacement, flush: true);
      try {
        await validate(pending);
        break;
      } on CliFailure catch (error) {
        if (repairEdits == null ||
            error.code != 'dart_validation_failed' ||
            attempt >= maxRepairs) {
          rethrow;
        }
        if (sha256.convert(await file.readAsBytes()) != hash) {
          throw const CliFailure('Source changed during editing. Retry with the current source.');
        }
        replacement = applyDartEdits(source, await repairEdits(source, error.message));
      }
    }
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock();
      if (sha256.convert(await file.readAsBytes()) != hash) {
        throw const CliFailure('Source changed during editing. Retry with the current source.');
      }
      final backupPending = File(p.join(directory.path, 'backup'));
      await backupPending.writeAsBytes(bytes, flush: true);
      await backupPending.rename(backup.absolute.path);
      // Recheck immediately before replacement, including non-cooperating tools.
      if (sha256.convert(await file.readAsBytes()) != hash) {
        throw const CliFailure('Source changed during editing. Retry with the current source.');
      }
      await pending.rename(file.absolute.path);
    } finally {
      await handle.unlock();
      await handle.close();
    }
    return (
      dartPath: file.absolute.path,
      backupPath: backup.absolute.path,
      sourceHash: sha256.convert(utf8.encode(replacement)).toString(),
    );
  } finally {
    if (pending.existsSync()) await pending.delete();
    await directory.delete(recursive: true);
  }
}
