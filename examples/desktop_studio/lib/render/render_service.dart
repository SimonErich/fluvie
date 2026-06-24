import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A rendered MP4 on disk.
class RenderResult {
  /// Creates a result for the file at [outputPath] of [bytes] length.
  const RenderResult({required this.outputPath, required this.bytes});

  /// Where the file was written.
  final String outputPath;

  /// The file size in bytes.
  final int bytes;
}

/// A render failure with a user-facing [message].
class RenderException implements Exception {
  /// Creates a render failure.
  const RenderException(this.message);

  /// The user-facing message.
  final String message;

  @override
  String toString() => message;
}

/// Renders a registered composition to a file by shelling out to the fluvie CLI.
///
/// A contract (not a typedef) so it is injected via Riverpod and faked in tests.
// ignore: one_member_abstracts
abstract interface class RenderService {
  /// Renders [key] to [outputPath]; pass [draft] to capture only the first
  /// frames for a fast preview render.
  Future<RenderResult> render({
    required String key,
    required String outputPath,
    bool draft = false,
  });
}

/// The real service: `dart run fluvie_cli:fluvie render <key> --out <path>`.
class CliRenderService implements RenderService {
  /// Creates the CLI-backed render service.
  const CliRenderService();

  @override
  Future<RenderResult> render({
    required String key,
    required String outputPath,
    bool draft = false,
  }) async {
    // An argument list, never a shell string, so paths with spaces are safe.
    final result = await Process.run('dart', [
      'run',
      'fluvie_cli:fluvie',
      'render',
      key,
      '--out',
      outputPath,
      if (draft) ...['--frames', '30'],
    ]);
    if (result.exitCode != 0) {
      throw RenderException(
        'The render failed (exit ${result.exitCode}).\n${result.stderr}',
      );
    }
    final file = File(outputPath);
    if (!file.existsSync()) {
      throw const RenderException(
        'The CLI reported success but wrote no file.',
      );
    }
    return RenderResult(outputPath: outputPath, bytes: file.lengthSync());
  }
}

/// The injected render service (overridden with a fake in tests).
final Provider<RenderService> renderServiceProvider = Provider<RenderService>(
  (ref) => const CliRenderService(),
);
