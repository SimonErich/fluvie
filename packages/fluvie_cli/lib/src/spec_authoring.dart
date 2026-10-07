import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:fluvie_cli/src/capture_process.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:path/path.dart' as p;

/// Authors once, publishes code/document, then optionally renders that code.
/// Rendering failures leave the independently useful authored artifacts intact.
Future<int> authorThenRender({
  required ProcessRunner runner,
  required Future<Directory> Function() createSandbox,
  required ArgResults args,
  required String outPath,
  required String specOut,
  required Map<String, String> defines,
  required ExportFlags flags,
  required int? frames,
  required StringSink out,
  required StringSink err,
  required FfmpegResolver resolveFfmpeg,
  String dartName = 'generated_video',
  Map<String, String>? environment,
}) async {
  final project = resolveProjectDir(project: args.option('project'));
  final pending = await Directory.systemTemp.createTemp('fluvie_authoring_');
  try {
    if (args.flag('machine')) {
      out.writeln(jsonEncode({'schemaVersion': 1, 'event': 'progress', 'stage': 'author'}));
    }
    final document = p.join(pending.path, 'composition.json');
    await captureThenEncode(
      runner: runner,
      createSandbox: createSandbox,
      args: args,
      key: '',
      outPath: outPath,
      frames: frames,
      flags: flags,
      extraDefines: {...defines, 'FLUVIE_OPERATION': 'author', 'FLUVIE_RENDER_SPEC_OUT': document},
      projectDirOverride: project,
      environment: environment,
      out: StringBuffer(),
      err: err,
      resolveFfmpeg: resolveFfmpeg,
    );
    final artifacts = await AuthoredArtifacts.publish(
      pendingSpec: document,
      specPath: specOut,
      projectDir: project,
      dartPath: args.option('dart-out'),
      name: dartName,
    );
    if (args.flag('machine')) {
      out.writeln(jsonEncode(artifacts.toJson()));
    } else {
      out
        ..writeln('Spec ${artifacts.specPath}')
        ..writeln('Dart ${artifacts.dartPath}')
        ..writeln('Preview: fluvie preview ${jsonEncode(artifacts.dartPath)}');
    }
    if (args.flag('no-render')) return 0;
    final target = resolveFileTarget(arg: artifacts.dartPath, entry: 'build', project: project);
    return await captureThenEncode(
      runner: runner,
      createSandbox: createSandbox,
      args: args,
      key: p.relative(target.path, from: project),
      outPath: outPath,
      frames: frames,
      flags: flags,
      extraDefines: const {},
      projectDirOverride: project,
      stage: (projectDir) =>
          stageManagedHarness(projectDir: projectDir, runner: runner, target: target),
      out: out,
      err: err,
      environment: environment,
      resolveFfmpeg: resolveFfmpeg,
    );
  } finally {
    await pending.delete(recursive: true);
  }
}
