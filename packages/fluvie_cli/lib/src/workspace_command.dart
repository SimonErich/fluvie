import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/workspace_server.dart';
import 'package:fluvie_cli/src/workspace_session.dart';
import 'package:path/path.dart' as p;

/// Starts a package-owned visual workspace and a lazy, persistent capture worker.
final class WorkspaceCommand {
  /// Uses native process execution for compilation and export.
  const WorkspaceCommand({this.runner = const IoProcessRunner()});

  /// Toolchain and encoder process seam.
  final ProcessRunner runner;

  /// Composition and managed-toolchain options.
  static ArgParser buildParser() => ArgParser()
    ..addOption('entry', defaultsTo: 'build', help: 'Top-level Video builder.')
    ..addOption('project', help: 'Source Flutter project.')
    ..addOption('ffmpeg', help: 'Explicit FFmpeg executable.')
    ..addOption('ffprobe', help: 'Explicit companion FFprobe executable.')
    ..addOption('toolchain', defaultsTo: 'managed', allowed: ['managed', 'system'])
    ..addFlag('no-download', negatable: false)
    ..addFlag('enable-impeller', negatable: false)
    ..addOption('startup-timeout', defaultsTo: '300', help: 'Worker ready timeout in seconds.')
    ..addOption('request-timeout', defaultsTo: '300', help: 'Engine request timeout in seconds.')
    ..addFlag('json', negatable: false, help: 'Emit the connection descriptor as JSON.');

  /// Keeps the server alive until interrupted. Generated results live in build/.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 1) {
      err.writeln('Use fluvie workspace <video.dart>.');
      return 64;
    }
    Duration timeout(String key) {
      final seconds = int.tryParse(args.option(key)!);
      if (seconds == null || seconds < 1) {
        throw CliFailure('Use positive whole seconds for --$key.');
      }
      return Duration(seconds: seconds);
    }

    final startupTimeout = timeout('startup-timeout');
    final requestTimeout = timeout('request-timeout');
    final target = resolveFileTarget(
      arg: args.rest.single,
      entry: args.option('entry')!,
      project: args.option('project'),
    );
    final tools = await ensureFfmpegToolchain(
      runner,
      binary: args.option('ffmpeg'),
      probeBinary: args.option('ffprobe'),
      mode: args.option('toolchain')!,
      allowDownload: !args.flag('no-download'),
      log: err.writeln,
    );
    final root = Directory(
      p.join(
        target.projectDir,
        'build',
        'fluvie',
        '${p.basenameWithoutExtension(target.path)}.workspace',
      ),
    )..createSync(recursive: true);
    final session = WorkspaceSession(
      target: target,
      directory: root,
      toolchain: tools,
      err: err,
      runner: runner,
      impeller: args.flag('enable-impeller'),
      workerStartupTimeout: startupTimeout,
      workerRequestTimeout: requestTimeout,
    );
    final server = await WorkspaceServer.start(session);
    final descriptor = p.join(root.path, 'session.json');
    final stop = Completer<void>();
    final signals = <StreamSubscription<ProcessSignal>>[];
    try {
      await atomicWrite(descriptor, jsonEncode(server.descriptor));
      if (!Platform.isWindows) {
        await runner.run('chmod', ['600', descriptor]);
        for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
          signals.add(
            signal.watch().listen((_) {
              if (!stop.isCompleted) stop.complete();
            }),
          );
        }
      }
      out.writeln(
        args.flag('json')
            ? jsonEncode({'event': 'workspace', 'sessionPath': descriptor, ...server.descriptor})
            : 'Workspace: ${server.url}\nAssistant connection: $descriptor\nPress Ctrl+C to stop.',
      );
      await stop.future;
      return 0;
    } finally {
      for (final signal in signals) {
        await signal.cancel();
      }
      await server.close();
      if (File(descriptor).existsSync()) await File(descriptor).delete();
    }
  }
}
