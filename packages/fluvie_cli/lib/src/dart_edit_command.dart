import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/dart_source_edit.dart';

/// Executes a native source edit through injectable authoring, validation, and
/// rendering boundaries. Source text is never round-tripped through VideoSpec.
Future<int> executeDartEdit({
  required ArgResults args,
  required StringSink out,
  required StringSink err,
  required Future<String> Function(String source) requestEdits,
  required Future<void> Function(File source) validate,
  required Future<int> Function(String source) render,
  Future<String> Function(String source, String feedback)? repairEdits,
  File? file,
}) async {
  final result = await editDartSource(
    file: file ?? File(args.rest.first),
    requestEdits: requestEdits,
    repairEdits: repairEdits,
    validate: validate,
  );
  if (args.flag('machine')) {
    out.writeln(
      jsonEncode({
        'schemaVersion': 1,
        'event': 'edited',
        'dartPath': result.dartPath,
        'sourceHash': result.sourceHash,
        'backupPath': result.backupPath,
      }),
    );
  } else {
    out
      ..writeln('Dart ${result.dartPath}')
      ..writeln('Backup ${result.backupPath}')
      ..writeln('Preview: fluvie preview ${jsonEncode(result.dartPath)}');
  }
  return args.flag('no-render') ? 0 : render(result.dartPath);
}
