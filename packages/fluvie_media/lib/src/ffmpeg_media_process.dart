part of 'ffmpeg_media_tools.dart';

extension _OwnedMediaProcess on FfmpegMediaTools {
  Future<MediaProcessResult> _runOwnedProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Future<void>? whenCancelled,
  }) async {
    if (_closed) throw StateError('Media tools have been closed.');
    final injected = _runner;
    if (injected != null) {
      return Future.any([
        injected(executable, arguments, workingDirectory: workingDirectory),
        if (whenCancelled != null)
          whenCancelled.then<MediaProcessResult>((_) => throw const MediaCancelledException()),
      ]).timeout(timeout);
    }
    final Process process;
    try {
      process = await _startProcess(executable, arguments, workingDirectory: workingDirectory);
    } on ProcessException catch (error) {
      throw MediaProcessException('Could not run "$executable": ${error.message}');
    }
    _processes.add(process);
    final stdoutDone = process.stdout.transform(utf8.decoder).join();
    var stderr = '';
    final stderrDone = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).forEach((
      chunk,
    ) {
      stderr = FfmpegMediaTools._tail('$stderr$chunk');
    });
    try {
      var cancelled = false;
      final code = await Future.any([
        process.exitCode,
        if (whenCancelled != null)
          whenCancelled.then((_) async {
            if (_processes.contains(process)) {
              cancelled = true;
              process.kill(ProcessSignal.sigkill);
            }
            return process.exitCode;
          }),
      ]).timeout(timeout);
      await stderrDone;
      final stdout = await stdoutDone;
      if (cancelled) throw const MediaCancelledException();
      return (exitCode: code, stdout: stdout, stderr: stderr);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      await stderrDone;
      await stdoutDone;
      throw MediaProcessException(
        '"$executable" timed out after ${timeout.inSeconds}s.',
        stderr: stderr,
      );
    } finally {
      _processes.remove(process);
    }
  }
}
