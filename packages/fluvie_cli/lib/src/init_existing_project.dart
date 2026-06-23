import 'dart:io';

import 'package:fluvie_cli/src/init_prompt.dart';
import 'package:fluvie_cli/src/init_support.dart';
import 'package:fluvie_cli/src/project_context.dart';
import 'package:fluvie_cli/src/templates/starter_composition_template.dart';

/// Drops a starter composition into an existing Flutter [context] and, when
/// asked, wires the render harness so `fluvie render <key>` works.
///
/// In [interactive] mode the file location and the render question are prompted
/// (Enter accepts the default); otherwise [pathOverride] and [withRender] decide.
/// Returns the process exit code.
Future<int> initExistingProject({
  required ProjectContext context,
  required InitPrompt prompt,
  required bool interactive,
  required String name,
  required String? pathOverride,
  required bool withRender,
  required bool force,
  required StringSink out,
  required StringSink err,
}) async {
  final names = namesFor(name);
  final dir = context.directory;
  final defaultPath = pathOverride ?? 'lib/videos/${names.fileName}';
  final relPath = interactive
      ? prompt.ask('Where should the composition go?', defaultValue: defaultPath)
      : defaultPath;

  final file = File('${dir.path}/$relPath');
  if (!writeFileIfAbsent(
    file,
    starterCompositionSource(functionName: names.functionName, key: names.key),
    force: force,
  )) {
    err.writeln('$relPath already exists. Pass --force to overwrite it.');
    return 1;
  }
  out.writeln('Created $relPath');

  final pubspec = File('${dir.path}/pubspec.yaml');
  if (!context.hasFluvieDependency &&
      ensureDependency(
        pubspec,
        section: 'dependencies',
        name: 'fluvie',
        version: fluvieDependencyVersion,
      )) {
    out.writeln('Added fluvie: $fluvieDependencyVersion to pubspec.yaml');
  }

  final doRender = interactive
      ? prompt.confirm('Scaffold a render harness so `fluvie render ${names.key}` works?')
      : withRender;
  if (doRender) {
    _scaffoldRender(context, dir, relPath, names, force: force, out: out, err: err);
  }

  out
    ..writeln()
    ..writeln('Next:')
    ..writeln('  flutter pub get')
    ..writeln('  fluvie render ${names.key} --out ${names.key}.mp4');
  return 0;
}

void _scaffoldRender(
  ProjectContext context,
  Directory dir,
  String relPath,
  ScaffoldNames names, {
  required bool force,
  required StringSink out,
  required StringSink err,
}) {
  final package = context.packageName;
  if (package == null) {
    err.writeln('Skipped the render harness: pubspec.yaml has no package name.');
    return;
  }
  if (!relPath.startsWith('lib/')) {
    err.writeln('Skipped the render harness: the composition must live under lib/ to import it.');
    return;
  }
  final written = writeRenderScaffold(
    projectDir: dir,
    packageName: package,
    names: names,
    libPath: relPath.substring('lib/'.length),
    force: force,
  );
  for (final path in written) {
    out.writeln('Created $path');
  }
  out.writeln('Added alchemist dev dependency for the render harness fonts.');
}
