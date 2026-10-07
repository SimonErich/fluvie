import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/local_media_bridge.dart';
import 'package:fluvie_cli/src/preview_app.dart';
import 'package:fluvie_cli/src/preview_audio.dart';
import 'package:fluvie_cli/src/preview_session.dart';
import 'package:fluvie_cli/src/process_runner.dart';

/// Invalidates cached adapters when the package preview contract changes.
const String previewCliVersion = '0.3.1-preview-3';

/// An addressable browser server is the default for humans and coding agents.
String defaultPreviewDevice() => 'web-server';

/// Platform scaffolds required by the chosen Flutter device.
List<String> platformsFor(String device) => switch (device) {
  'chrome' || 'web-server' => const ['web'],
  'linux' => const ['linux'],
  'macos' => const ['macos'],
  'windows' => const ['windows'],
  _ => const ['android', 'ios'],
};

/// Runs a live package-owned preview host outside the authoring project.
final class PreviewCommand {
  /// Process and scaffold seams keep command validation independently testable.
  PreviewCommand({this._runner = const IoProcessRunner(), this._ensureApp = ensurePreviewApp});
  final ProcessRunner _runner;
  final Future<String> Function({
    required ProcessRunner runner,
    required FileTarget target,
    required List<String> platforms,
    required String cliVersion,
    required StringSink out,
    Map<String, String>? environment,
  })
  _ensureApp;

  /// Live browser/desktop preview options.
  static ArgParser buildParser() => ArgParser(usageLineLength: 80)
    ..addOption(
      'device',
      abbr: 'd',
      help: 'Flutter device (default: web-server; chrome opens Chrome).',
    )
    ..addOption('entry', defaultsTo: 'build', help: 'Top-level function returning Video.')
    ..addOption('project', help: 'Source Flutter project.')
    ..addOption('ffmpeg', help: 'Explicit FFmpeg executable.')
    ..addOption('ffprobe', help: 'Explicit FFprobe executable.')
    ..addOption(
      'toolchain',
      allowed: ['managed', 'system'],
      defaultsTo: 'managed',
      help: 'Pinned managed pair or installed system pair.',
    )
    ..addFlag(
      'no-download',
      negatable: false,
      help: 'Use an already provisioned or explicit toolchain.',
    )
    ..addFlag('json', negatable: false, help: 'Emit ready URL and reload events as JSON lines.');

  /// Keeps bridge, audio workspace and Flutter process alive until preview exits.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 1) {
      err.writeln('preview needs exactly one composition file.\n\n${buildParser().usage}');
      return 64;
    }
    final device = args.option('device') ?? defaultPreviewDevice();
    LocalMediaBridge? bridge;
    final audioWorkspaces = <Directory>[];
    try {
      final target = resolveFileTarget(
        arg: args.rest.single,
        entry: args.option('entry') ?? 'build',
        project: args.option('project'),
      );
      final appDir = await _ensureApp(
        runner: _runner,
        target: target,
        platforms: platformsFor(device),
        cliVersion: previewCliVersion,
        out: args.flag('json') ? err : out,
      );
      final tools = await ensureFfmpegToolchain(
        _runner,
        binary: args.option('ffmpeg'),
        probeBinary: args.option('ffprobe'),
        mode: args.option('toolchain') ?? 'managed',
        allowDownload: !args.flag('no-download'),
        log: err.writeln,
      );
      bridge =
          await LocalMediaBridge.start(
              toolchain: tools,
              projectDir: Directory(target.projectDir),
            )
            ..setAudioProvider(() async {
              final workspace = await Directory.systemTemp.createTemp('fluvie_preview_audio_');
              audioWorkspaces.add(workspace);
              return preparePreviewAudio(
                runner: _runner,
                target: target,
                toolchain: tools,
                workspace: workspace,
                err: err,
              );
            });
      final process = await Process.start(
        'flutter',
        [
          'run',
          '--machine',
          '--no-pub',
          '-d',
          device,
          '--dart-define=FLUVIE_PREVIEW_ENDPOINT=${bridge.endpoint}',
          '--dart-define=FLUVIE_PREVIEW_TOKEN=${bridge.sessionToken}',
          '--dart-define=FLUVIE_PROJECT_DIR=${target.projectDir}',
          '--dart-define=FLUVIE_FFMPEG=${tools.ffmpegPath}',
          '--dart-define=FLUVIE_FFPROBE=${tools.ffprobePath}',
        ],
        workingDirectory: appDir,
        environment: tools.environment,
      );
      return await PreviewSession(
        process: process,
        projectDir: target.projectDir,
        device: device,
        out: out,
        err: err,
        json: args.flag('json'),
        onReload: bridge.notifyReload,
      ).run();
    } on CliFailure catch (failure) {
      err.writeln(failure.message);
      return 1;
    } on ProcessException catch (error) {
      err.writeln(
        'Could not run "flutter" (${error.message}). Install Flutter and put flutter on PATH (https://docs.flutter.dev/get-started/install).',
      );
      return 1;
    } finally {
      await bridge?.close();
      for (final workspace in audioWorkspaces) {
        if (workspace.existsSync()) await workspace.delete(recursive: true);
      }
    }
  }
}
