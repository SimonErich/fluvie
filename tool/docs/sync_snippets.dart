import 'dart:io';

import '../src/sync_snippets.dart';

/// Syncs the documentation code fences with their compiled snippet sources.
///
/// Usage:
///   dart run tool/docs/sync_snippets.dart            # rewrite in place
///   dart run tool/docs/sync_snippets.dart --check    # CI: fail on drift
///
/// Each `<!-- code-excerpt "<file> (<region>)" -->` directive in
/// `documentation/**/*.md` is followed by a ```dart fence whose body is filled
/// from the named `// #docregion` in the source file. `--check` changes nothing
/// and exits non-zero if any fence has drifted or any reference is broken.
void main(List<String> args) {
  final check = args.contains('--check');
  final root = Directory.current.path;

  final result = syncSnippets(rootDir: root, check: check);

  for (final error in result.errors) {
    stderr.writeln('error: $error');
  }
  for (final report in result.drift) {
    stderr.writeln('drift: $report');
  }

  if (check) {
    if (result.exitCode == 0) {
      stdout.writeln('docs:snippets:check — all fences in sync.');
    } else {
      stderr.writeln(
        '\n${result.drift.length} fence(s) out of sync, '
        '${result.errors.length} error(s). Run `melos run docs:snippets`.',
      );
    }
  } else {
    if (result.changed.isEmpty && result.errors.isEmpty) {
      stdout.writeln('docs:snippets — nothing to update.');
    } else {
      for (final file in result.changed) {
        stdout.writeln('updated: $file');
      }
    }
  }

  exitCode = result.exitCode;
}
