import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/init_support.dart';
import 'package:fluvie_cli/src/templates/project_scaffold_template.dart';
import 'package:path/path.dart' as p;

/// Scaffolds a Fluvie project in [dir]: the pubspec, the analysis options, a
/// starter composition under `lib/`, and an empty `assets/`.
///
/// Nothing else. There is no app, no capture harness, no registry, and no
/// platform directories: `flutter test` needs only a pubspec in its working
/// directory, and renders reuse a package-managed external adapter. What is
/// left is the composition and its media, which is the whole project.
///
/// Compositions under `lib/` keep canonical package imports. Files elsewhere
/// can also render and preview through an absolute import adapter.
///
/// Every file is written only when absent unless [force], so re-running `init`
/// in a project is safe and reports what it skipped.
Future<int> initProject({
  required Directory dir,
  required String fileName,
  required bool force,
  required StringSink out,
  required StringSink err,
  String? fluviePath,
  bool withLints = false,
  bool withAi = false,
}) async {
  final localFluviePath = fluviePath == null ? null : resolveFluviePath(fluviePath);
  final packageName = packageNameFor(dir.path);
  final wrote = <String>[];
  final skipped = <String>[];

  void write(String relative, String content) {
    final file = File(p.join(dir.path, relative));
    if (writeFileIfAbsent(file, content, force: force)) {
      wrote.add(relative);
    } else {
      skipped.add(relative);
    }
  }

  final composition = p.url.join('lib', fileName);
  final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
  if (pubspec.existsSync()) {
    if (ensureFluvieDependencies(
      pubspec,
      fluviePath: localFluviePath,
      withLints: withLints,
      withAi: withAi,
    )) {
      wrote.add('pubspec.yaml (merged dependencies)');
    } else {
      skipped.add('pubspec.yaml');
    }
  } else {
    write('pubspec.yaml', projectPubspecSource(packageName: packageName));
    if (fluviePath != null || withLints || withAi) {
      ensureFluvieDependencies(
        pubspec,
        fluviePath: localFluviePath,
        withLints: withLints,
        withAi: withAi,
      );
    }
  }
  if (ensureProjectGitignore(File(p.join(dir.path, '.gitignore')), projectGitignoreSource())) {
    wrote.add('.gitignore');
  } else {
    skipped.add('.gitignore');
  }
  write(composition, starterCompositionSource(fileName: fileName));
  // A .gitkeep so the directory survives a clone; the CLI derives the pubspec's
  // assets block from whatever is in here.
  write(p.join('assets', '.gitkeep'), '');
  final analysis = File(p.join(dir.path, 'analysis_options.yaml'));
  if (withLints) {
    ensureCustomLintPlugin(analysis);
  } else if (!analysis.existsSync() && pubspec.readAsStringSync().contains('flutter_lints:')) {
    analysis.writeAsStringSync('include: package:flutter_lints/flutter.yaml\n');
  }

  if (wrote.isEmpty) {
    out.writeln('Fluvie is already configured in ${dir.path}.');
    return 0;
  }
  for (final file in wrote) {
    out.writeln('  created $file');
  }
  for (final file in skipped) {
    out.writeln('  skipped $file (already exists)');
  }
  out
    ..writeln()
    ..writeln('Next:')
    ..writeln('  flutter pub get')
    ..writeln('  fluvie preview ./$composition')
    ..writeln('  fluvie render ./$composition');
  return 0;
}

/// A pub-legal package name derived from [dirPath]'s last segment.
///
/// Lowercased with every non-identifier character folded to `_`; an empty or
/// digit-leading result gets a prefix, because a package name must be a valid
/// Dart identifier and `import 'package:2_cats/...'` does not parse.
String packageNameFor(String dirPath) {
  final base = p.basename(p.absolute(dirPath)).toLowerCase();
  final safe = base.replaceAll(RegExp('[^a-z0-9_]'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (safe.isEmpty) return 'fluvie_video';
  return RegExp('^[0-9]').hasMatch(safe) ? 'app_$safe' : safe;
}

/// Fails when [dir] already holds a non-Flutter package, so scaffolding into it
/// would collide with something the user did not mean to hand to Fluvie.
void assertScaffoldable(Directory dir) {
  if (!dir.existsSync()) return;
  final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return;
  if (isFlutterAppPubspec(pubspec)) return;
  throw CliFailure(
    'A pubspec.yaml already exists in "${dir.path}" and it is not a Flutter '
    'project. Run `fluvie init` in an empty directory, or pass --force.',
  );
}

/// Whether `pubspec` declares a `flutter` dependency, so it is a Flutter project
/// and a composition can be dropped into it.
bool isFlutterAppPubspec(File pubspec) =>
    pubspec.readAsLinesSync().any((line) => RegExp(r'^\s+flutter\s*:').hasMatch(line));
