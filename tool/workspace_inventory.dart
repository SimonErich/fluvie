import 'dart:convert';
import 'dart:io';

import 'src/workspace_inventory_loader.dart';

/// Lists or validates source-derived analysis, test, coverage and release targets.
void main(List<String> arguments) {
  var root = Directory.current;
  var mode = '--check';
  var selected = false;
  const modes = {
    '--check',
    '--json',
    '--coverage',
    '--coverage-files',
    '--publishable',
    '--dartdoc',
  };
  try {
    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument == '--root' && i + 1 < arguments.length) {
        root = Directory(arguments[++i]);
      } else if (modes.contains(argument) && !selected) {
        mode = argument;
        selected = true;
      } else {
        throw const FormatException('Choose one inventory output and an optional --root directory');
      }
    }
    final inventory = loadWorkspaceInventory(root);
    if (mode == '--json') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(inventory.toJson()));
    } else if (inventory.problems.isEmpty) {
      stdout.writeln(switch (mode) {
        '--coverage' => inventory.coveragePaths.join('\n'),
        '--coverage-files' => inventory.coverageFiles.join(','),
        '--publishable' => inventory.publishableNames.join('\n'),
        '--dartdoc' => inventory.dartdocPaths.join('\n'),
        _ =>
          'Checked ${inventory.targets.length} workspace targets; ${inventory.coveragePaths.length} production coverage targets.',
      });
    }
    if (inventory.problems.isNotEmpty) {
      inventory.problems.forEach(stderr.writeln);
      exitCode = 1;
    }
  } on Object catch (error) {
    stderr.writeln('Workspace inventory failed: $error');
    exitCode = 64;
  }
}
