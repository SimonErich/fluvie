import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/capture_process.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:path/path.dart' as p;

/// Prepares the composition's real audio mix without capturing video frames.
/// The caller owns [workspace] until the bridge has finished serving its WAV.
Future<File> preparePreviewAudio({
  required ProcessRunner runner,
  required FileTarget target,
  required FfmpegToolchain toolchain,
  required Directory workspace,
  required StringSink err,
}) async {
  final harness = await stageManagedHarness(
    projectDir: target.projectDir,
    runner: runner,
    target: target,
  );
  await runCapture(
    runner: runner,
    projectDir: target.projectDir,
    key: '',
    sandbox: workspace,
    harnessPath: harness.harnessPath,
    packageConfigPath: harness.packageConfigPath,
    extraDefines: {
      'FLUVIE_OPERATION': 'audio',
      'FLUVIE_PROJECT_DIR': target.projectDir,
      'FLUVIE_FFMPEG': toolchain.ffmpegPath,
      'FLUVIE_FFPROBE': toolchain.ffprobePath,
    },
    environment: toolchain.environment,
    err: err,
  );
  final manifest = File(p.join(workspace.path, 'audio-mix.json'));
  if (!manifest.existsSync()) {
    throw const CliFailure('The preview audio preparation did not produce audio-mix.json.');
  }
  final json = jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
  if (json['schemaVersion'] != 1 ||
      json['outputFileName'] != 'audio.wav' ||
      json['ffmpegArgs'] is! List) {
    throw const CliFailure('The preview audio recipe has an unsupported schema.');
  }
  final args = (json['ffmpegArgs']! as List).cast<String>();
  final result = await runner.run(
    toolchain.ffmpegPath,
    args,
    workingDirectory: workspace.path,
    environment: toolchain.environment,
  );
  final audio = File(p.join(workspace.path, 'audio.wav'));
  if (result.exitCode != 0 || !audio.existsSync()) {
    throw CliFailure('Could not prepare the preview audio mix.\n${result.stderr}');
  }
  return audio;
}
