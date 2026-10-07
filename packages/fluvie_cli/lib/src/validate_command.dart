import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_validate/fluvie_validate.dart';

/// An injectable, non-executing file validation boundary.
typedef FileValidator = Future<List<FluvieDiagnostic>> Function(FileTarget target);

/// Static checks for an authored Dart composition and its original imports.
final class ValidateCommand {
  /// Creates validation with an optional analyzer seam.
  // ignore: prefer_initializing_formals — retain the public injection name.
  const ValidateCommand({FileValidator? validator}) : _validator = validator;

  final FileValidator? _validator;

  /// Options for `fluvie validate <file.dart>`.
  static ArgParser buildParser() => ArgParser()
    ..addFlag(
      'json',
      negatable: false,
      help: 'Print source locations and diagnostic codes as JSON.',
    )
    ..addOption('project', help: 'Use the package resolution in this project.');

  /// Returns 1 for compiler errors, 0 for compilable code, and 64 for bad usage.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 1 || !args.rest.single.endsWith('.dart')) {
      err.writeln('validate requires one Dart file.\n${buildParser().usage}');
      return 64;
    }
    final path = File(args.rest.single).absolute.path;
    try {
      final target = resolveFileTarget(arg: path, entry: 'build', project: args.option('project'));
      final diagnostics = await (_validator ?? _analyzeFile)(target);
      final ok = !diagnostics.any((d) => d.severity == FluvieDiagnosticSeverity.error);
      if (args.flag('json')) {
        out.writeln(
          jsonEncode({
            'schemaVersion': 1,
            'ok': ok,
            'path': target.path,
            'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
          }),
        );
      } else {
        for (final diagnostic in diagnostics) {
          out.writeln(
            '${target.path}:${diagnostic.line}:${diagnostic.column}: '
            '${diagnostic.severity.name}: ${diagnostic.message}'
            '${diagnostic.code == null ? '' : ' [${diagnostic.code}]'}',
          );
        }
        if (diagnostics.isEmpty) out.writeln('Valid: ${target.path}');
      }
      return ok ? 0 : 1;
    } on Object catch (error) {
      if (args.flag('json')) {
        out.writeln(
          jsonEncode({
            'schemaVersion': 1,
            'ok': false,
            'path': path,
            'diagnostics': <Object?>[],
            'error': '$error',
          }),
        );
      } else {
        err.writeln('Could not validate "$path": $error');
      }
      return 1;
    }
  }

  static Future<List<FluvieDiagnostic>> _analyzeFile(FileTarget target) async {
    final analyzer = FluvieCodeAnalyzer(projectRoot: Directory(target.projectDir));
    try {
      return await analyzer.analyzeFile(target.path);
    } finally {
      await analyzer.dispose();
    }
  }
}
