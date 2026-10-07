import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/output_verification.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart' show createRenderSandbox;
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:fluvie_cli/src/render_receipt.dart';
import 'package:fluvie_cli/src/review_quality.dart';
import 'package:fluvie_cli/src/validate_command.dart';
import 'package:path/path.dart' as p;

/// Managed preparation and artifact verification for one review invocation.
final class ReviewWorkflow {
  const ReviewWorkflow({required this.runner, required this.err});
  final ProcessRunner runner;
  final StringSink err;

  Future<Map<String, Object?>> validate(FileTarget target) async {
    final out = StringBuffer();
    await const ValidateCommand().execute(
      ValidateCommand.buildParser().parse([target.path, '--project', target.projectDir, '--json']),
      out: out,
      err: err,
    );
    return jsonDecode(out.toString()) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> capture(FileTarget target, ArgResults args, String output) async {
    final report = p.join(output, 'mounted.json');
    await captureThenEncode(
      runner: runner,
      createSandbox: createRenderSandbox,
      args: args,
      key: p.relative(target.path, from: target.projectDir),
      outPath: report,
      frames: validateFrames(args.option('frames')),
      flags: validateExportFlags(args),
      extraDefines: {
        'FLUVIE_OPERATION': 'review',
        'FLUVIE_REVIEW_FRAMES': args.multiOption('samples').join(','),
        'FLUVIE_REVIEW_DETERMINISM': '${args.flag('determinism')}',
        'FLUVIE_REVIEW_OUT_DIR': p.absolute(output),
      },
      projectDirOverride: target.projectDir,
      noCacheOverride: true,
      stage: (project) => stageManagedHarness(projectDir: project, runner: runner, target: target),
      out: StringBuffer(),
      err: err,
    );
    return jsonDecode(await File(report).readAsString()) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> render(FileTarget target, ArgResults args, String output) async {
    final file = p.join(
      output,
      p.basename(defaultRenderOutput(target.projectDir, 'video', format: args.option('format'))),
    );
    try {
      await captureThenEncode(
        runner: runner,
        createSandbox: createRenderSandbox,
        args: args,
        key: p.relative(target.path, from: target.projectDir),
        outPath: file,
        frames: validateFrames(args.option('frames')),
        flags: validateExportFlags(args),
        extraDefines: const {},
        projectDirOverride: target.projectDir,
        stage: (project) =>
            stageManagedHarness(projectDir: project, runner: runner, target: target),
        out: StringBuffer(),
        err: err,
      );
    } on CliFailure catch (failure) {
      if (failure.code != 'output_verification_failed') rethrow;
      return {'event': 'artifactFailure', 'filePath': file, ...failure.details};
    }
    final receiptPath = p.join(p.dirname(file), '${p.basenameWithoutExtension(file)}.render.json');
    final receipt = jsonDecode(await File(receiptPath).readAsString()) as Map<String, Object?>;
    final audio = await reviewArtifactAudio(receipt, runner);
    if (!args.flag('strict-decode')) {
      return {...renderArtifactEvent(receipt), 'audioQuality': audio};
    }
    final capture = receipt['capture'];
    final intent =
        capture is Map<String, Object?> && capture['outputIntent'] is Map<String, Object?>
        ? capture['outputIntent']! as Map<String, Object?>
        : const <String, Object?>{};
    final toolchain = receipt['toolchain']! as Map<String, Object?>;
    final check = await verifyOutput(
      file,
      expected: intent,
      strictDecode: true,
      ffmpegBinary: toolchain['ffmpegPath'] as String? ?? toolchain['ffmpeg'] as String?,
      ffprobeBinary: toolchain['ffprobePath'] as String? ?? toolchain['ffprobe'] as String?,
      runner: runner,
    );
    return {
      ...renderArtifactEvent(receipt),
      'verification': {...check}..remove('probe'),
      'audioQuality': audio,
    };
  }
}

/// Measures an encoded artifact only when its receipt records an audio stream.
/// Missing tools or a non-audio export are reported as explicit unchecked scope.
Future<Map<String, Object?>> reviewArtifactAudio(
  Map<String, Object?> receipt,
  ProcessRunner runner,
) async {
  final capture = receipt['capture'] as Map<String, Object?>?;
  final intent = capture?['outputIntent'] as Map<String, Object?>?;
  final toolchain = receipt['toolchain'] as Map<String, Object?>?;
  final fps = capture?['fps'];
  if (intent?['hasAudio'] != true && intent?['audio'] != true) {
    return {
      'checked': false,
      'applicable': false,
      'reason': 'This export has no declared audio stream.',
      'findings': <Object?>[],
    };
  }
  if (fps is! int || toolchain?['ffmpeg'] is! String || receipt['filePath'] is! String) {
    return {
      'checked': false,
      'error': 'The receipt lacks audio measurement inputs.',
      'findings': <Object?>[],
    };
  }
  return inspectOutputAudio(
    runner: runner,
    ffmpeg: toolchain!['ffmpeg']! as String,
    path: receipt['filePath']! as String,
    fps: fps,
  );
}
