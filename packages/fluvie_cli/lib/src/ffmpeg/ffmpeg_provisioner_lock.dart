part of 'ffmpeg_provisioner.dart';

Future<void> _acquireProvisionLock(
  RandomAccessFile lock,
  String path,
  Duration timeout,
  ProvisionLog log,
) async {
  final clock = Stopwatch()..start();
  var nextMessage = Duration.zero;
  while (true) {
    try {
      await lock.lock();
      return;
    } on FileSystemException catch (error) {
      // EAGAIN/EACCES on Unix, EWOULDBLOCK on macOS, LOCK_VIOLATION on Windows.
      if (!const {11, 13, 33, 35}.contains(error.osError?.errorCode)) rethrow;
    }
    final elapsed = clock.elapsed;
    if (elapsed >= timeout) {
      throw CliFailure(
        'Another process is installing this FFmpeg toolchain ($path). '
        'Wait for it to finish and retry, or use --toolchain system with '
        'FFmpeg and ffprobe on PATH. The existing installation was preserved.',
        code: 'toolchain_busy',
        details: {'lockPath': path, 'waitSeconds': elapsed.inMilliseconds / 1000},
      );
    }
    if (elapsed >= nextMessage) {
      log('Waiting for another FFmpeg installation ($path; ${elapsed.inSeconds}s elapsed).');
      nextMessage = elapsed + const Duration(seconds: 5);
    }
    final remaining = timeout - elapsed;
    await Future<void>.delayed(
      remaining < const Duration(milliseconds: 100) ? remaining : const Duration(milliseconds: 100),
    );
  }
}
