import 'dart:io';

/// Starts a native process with argument arrays, never a shell command.
///
/// The returned process supplies binary stdout, diagnostic stderr and an exit
/// future. Its owner can terminate it with [Process.kill]. Tests can inject an
/// in-memory process; production defaults to [Process.start].
typedef MediaProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
