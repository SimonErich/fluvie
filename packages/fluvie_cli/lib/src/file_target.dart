import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:path/path.dart' as p;

/// One composition file a render or preview points at: the [projectDir] holding
/// it, its absolute [path], and the [entry] function to call.
final class FileTarget {
  /// Creates a resolved file target.
  const FileTarget({required this.projectDir, required this.path, required this.entry});

  /// The Fluvie project the target lives in (the `flutter test` working
  /// directory, and the pubspec that resolves its imports).
  final String projectDir;

  /// The absolute path of the composition file.
  final String path;

  /// The top-level function returning the `Video` (`build` by convention).
  final String entry;

  /// This target's `package:` URI, or `null` when it does not live under `lib/`.
  ///
  /// A file outside `lib/` has no package URI at all, so only an importer inside
  /// the same package can reach it.
  String? get packageUri {
    final libDir = p.join(projectDir, 'lib');
    if (!p.isWithin(libDir, path)) return null;
    final name = packageNameOf(projectDir);
    if (name == null) return null;
    // Posix joins via the path package, never concatenation: an import URI uses
    // forward slashes on every platform.
    return 'package:$name/${p.url.joinAll(p.split(p.relative(path, from: libDir)))}';
  }

  /// The import URI a file in [fromDir] uses to reach this target.
  ///
  /// A target under `lib/` is imported by its [packageUri]. A relative import
  /// would give the same file a second library identity (the analyzer treats
  /// `package:x/a.dart` and `../lib/a.dart` as different libraries, so its types
  /// would not match) and it trips `avoid_relative_lib_imports`.
  ///
  /// Anywhere else the only identity is a relative path, which means only an
  /// importer inside the same package can reach it: a relative import cannot
  /// escape a package. The staged render harness lives in the project, so it can;
  /// the preview app does not, which is why it requires [packageUri].
  String importFrom(String fromDir) =>
      packageUri ?? p.url.joinAll(p.split(p.relative(path, from: fromDir)));
}

/// Whether [arg] names a composition file rather than a legacy registry key.
///
/// A `.dart` suffix or an existing file is a target; anything else is a key, so
/// `fluvie render starter` keeps resolving through the registry.
bool isFileTarget(String arg) => arg.endsWith('.dart') || File(arg).existsSync();

/// Resolves [arg] into a [FileTarget], failing with a stated reason when the
/// file or its project is missing.
FileTarget resolveFileTarget({required String arg, required String entry, String? project}) {
  // Normalized, so `./my_clip.dart` does not leave a `/.` segment in the project
  // path the CLI then prints and stages into.
  final path = p.normalize(p.absolute(arg));
  if (!File(path).existsSync()) {
    throw CliFailure('No such composition file: "$arg".');
  }
  final projectDir = p.normalize(p.absolute(project ?? _projectAbove(path)));
  return FileTarget(projectDir: projectDir, path: path, entry: entry);
}

/// The nearest ancestor of [path] holding a `pubspec.yaml`.
String _projectAbove(String path) {
  var dir = p.dirname(path);
  while (true) {
    if (File(p.join(dir, 'pubspec.yaml')).existsSync()) return dir;
    final parent = p.dirname(dir);
    if (parent == dir) {
      throw CliFailure(
        'No pubspec.yaml at or above "${p.relative(path)}", so there is no '
        'Flutter project to render it in. Run `fluvie init` in the directory '
        'holding your composition.',
      );
    }
    dir = parent;
  }
}

/// The `name:` of the package rooted at [dir], or `null` when it has none.
String? packageNameOf(String dir) {
  final pubspec = File(p.join(dir, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;
  for (final line in pubspec.readAsLinesSync()) {
    final match = RegExp(r'^name:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*$').firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}
