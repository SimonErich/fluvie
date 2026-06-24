import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';

/// The local desktop launcher: spawns
/// `dart run <root>/packages/fluvie_cli/bin/fluvie.dart render <key> --out build/<key>.mp4`
/// from the workspace root. Needs a Dart SDK and ffmpeg, so it only works on a
/// desktop run from a source checkout (not on web).
///
/// The root is located by [findWorkspaceRoot] rather than assumed to be the
/// current directory, so the launcher works both from a `dart`/`flutter test`
/// run (cwd inside the repo) and from a packaged desktop app (whose cwd is the
/// app bundle, not the source tree).
///
/// Arguments are passed as a list, never a shell string, and [render] rejects
/// any key that is not lowercase snake_case before a process is spawned.
final class ProcessRenderLauncher implements RenderLauncher {
  /// Creates the process-backed launcher.
  const ProcessRenderLauncher();

  static final RegExp _keyShape = RegExp(r'^[a-z0-9_]+$');

  /// The CLI entrypoint, relative to the workspace root. Its presence is also
  /// the marker [findWorkspaceRoot] searches for, since it is exactly the file
  /// the render spawns.
  static const cliEntrypoint = 'packages/fluvie_cli/bin/fluvie.dart';

  /// How often the progress file is polled while a render runs.
  static const _pollInterval = Duration(milliseconds: 100);

  @override
  Future<RenderLaunchResult> render(String key, {void Function(RenderProgress)? onProgress}) async {
    if (!_keyShape.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'composition keys are lowercase snake_case');
    }
    final root = findWorkspaceRoot([
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ]);
    final progressDir = Directory.systemTemp.createTempSync('fluvie_progress_');
    final progressFile = File('${progressDir.path}/progress');
    Timer? poll;
    if (onProgress != null) {
      poll = Timer.periodic(_pollInterval, (_) => _emitProgress(progressFile, onProgress));
    }
    try {
      final result = await Process.run(
        'dart',
        ['run', '${root.path}/$cliEntrypoint', 'render', key, '--out', 'build/$key.mp4'],
        workingDirectory: root.path,
        environment: {'FLUVIE_PROGRESS_FILE': progressFile.path},
      );
      if (onProgress != null) _emitProgress(progressFile, onProgress);
      return RenderLaunchResult(
        exitCode: result.exitCode,
        stdout: '${result.stdout}',
        stderr: '${result.stderr}',
      );
    } finally {
      poll?.cancel();
      if (progressDir.existsSync()) progressDir.deleteSync(recursive: true);
    }
  }

  static void _emitProgress(File file, void Function(RenderProgress) onProgress) {
    final progress = readProgress(file);
    if (progress != null) onProgress(progress);
  }

  /// Parses `"<completed>/<total>"` from [file], or `null` when it is absent or
  /// not yet a complete `int/int` line — so a torn read mid-write is tolerated.
  @visibleForTesting
  static RenderProgress? readProgress(File file) {
    if (!file.existsSync()) return null;
    final parts = file.readAsStringSync().trim().split('/');
    if (parts.length != 2) return null;
    final completed = int.tryParse(parts[0]);
    final total = int.tryParse(parts[1]);
    if (completed == null || total == null) return null;
    return RenderProgress(completed: completed, total: total);
  }

  /// Finds the workspace root among [anchors]: the nearest ancestor of any
  /// anchor that contains the CLI entrypoint ([cliEntrypoint]).
  @visibleForTesting
  static Directory findWorkspaceRoot(Iterable<Directory> anchors) {
    for (final anchor in anchors) {
      for (Directory? dir = anchor; dir != null; dir = _parentOrNull(dir)) {
        if (File('${dir.path}/$cliEntrypoint').existsSync()) return dir;
      }
    }
    throw const FileSystemException(
      'Could not locate the Fluvie workspace root (no $cliEntrypoint above the '
      'app). Rendering needs a source checkout; run the inspector from the repo.',
    );
  }

  static Directory? _parentOrNull(Directory dir) {
    final parent = dir.parent;
    return parent.path == dir.path ? null : parent;
  }
}
