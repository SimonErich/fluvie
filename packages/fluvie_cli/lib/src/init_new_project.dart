import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/init_prompt.dart';
import 'package:fluvie_cli/src/init_support.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/templates/preview_app_template.dart';
import 'package:fluvie_cli/src/templates/starter_composition_template.dart';

/// Scaffolds a minimal, runnable Fluvie project: `flutter create` for the app
/// skeleton, then a starter composition, a live-preview `main.dart`, the render
/// harness, and a widget test.
///
/// In [interactive] mode the user confirms and names the project (Enter accepts
/// the default); otherwise [dirOverride] (or `my_fluvie_video`) is used. Returns
/// the process exit code.
Future<int> initNewProject({
  required ProcessRunner runner,
  required InitPrompt prompt,
  required bool interactive,
  required Directory cwd,
  required String name,
  required String? dirOverride,
  required StringSink out,
  required StringSink err,
}) async {
  if (interactive && !prompt.confirm('No Flutter project here. Create a minimal Fluvie project?')) {
    out.writeln('Nothing created.');
    return 0;
  }
  final defaultDir = dirOverride ?? 'my_fluvie_video';
  final dirName = interactive
      ? prompt.ask('Project directory', defaultValue: defaultDir)
      : defaultDir;
  final package = packageNameFor(dirName);

  out.writeln('Creating a Flutter project in $dirName/ ...');
  final ProcessRunResult created;
  try {
    created = await runner.run('flutter', [
      'create',
      '--project-name',
      package,
      dirName,
    ], workingDirectory: cwd.path);
  } on ProcessException catch (error) {
    throw CliFailure(
      'Could not run "flutter create" (${error.message}). Install Flutter and '
      'make sure `flutter` is on PATH (https://docs.flutter.dev/get-started/install).',
    );
  }
  if (created.exitCode != 0) {
    throw CliFailure('flutter create failed (exit ${created.exitCode}).\n${created.stderr}');
  }

  final projectDir = Directory(dirName).isAbsolute
      ? Directory(dirName)
      : Directory('${cwd.path}/$dirName');
  final names = namesFor(name);
  final libPath = 'videos/${names.fileName}';

  writeFileIfAbsent(
    File('${projectDir.path}/lib/$libPath'),
    starterCompositionSource(functionName: names.functionName, key: names.key),
    force: true,
  );
  writeFileIfAbsent(
    File('${projectDir.path}/lib/main.dart'),
    previewAppSource(
      importLine: "import 'package:$package/$libPath';",
      functionName: names.functionName,
      title: 'Fluvie preview',
    ),
    force: true,
  );
  // The counter test `flutter create` writes imports the old main; drop it.
  final defaultTest = File('${projectDir.path}/test/widget_test.dart');
  if (defaultTest.existsSync()) defaultTest.deleteSync();

  writeRenderScaffold(
    projectDir: projectDir,
    packageName: package,
    names: names,
    libPath: libPath,
    force: true,
  );
  ensureDependency(
    File('${projectDir.path}/pubspec.yaml'),
    section: 'dependencies',
    name: 'fluvie',
    version: fluvieDependencyVersion,
  );

  out
    ..writeln('Created a Fluvie project in $dirName/')
    ..writeln()
    ..writeln('Next:')
    ..writeln('  cd $dirName')
    ..writeln('  flutter pub get')
    ..writeln('  flutter run                                    # live preview')
    ..writeln('  fluvie render ${names.key} --out ${names.key}.mp4              # render an MP4');
  return 0;
}

/// Turns a directory [dirName] into a valid Dart package name (lowercase,
/// underscores, leading letter).
String packageNameFor(String dirName) {
  final base = dirName.split(Platform.pathSeparator).last;
  final sanitized = base.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_');
  final trimmed = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
  final safe = trimmed.isEmpty ? 'fluvie_video' : trimmed;
  return RegExp('^[a-z]').hasMatch(safe) ? safe : 'app_$safe';
}
