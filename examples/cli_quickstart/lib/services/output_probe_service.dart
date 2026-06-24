import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A rendered output file found on disk.
class RenderOutput {
  /// Creates a record of the rendered file at [path] of [bytes] length.
  const RenderOutput({required this.path, required this.bytes});

  /// The path the file was found at.
  final String path;

  /// The file size in bytes.
  final int bytes;
}

/// Reports whether the CLI has produced the quickstart MP4 yet.
abstract interface class OutputProbeService {
  /// The default path the quickstart render command writes to.
  String get outputPath;

  /// The rendered file, or null when it does not exist yet.
  Future<RenderOutput?> probe();
}

/// Reads the output file from the local filesystem.
class IoOutputProbeService implements OutputProbeService {
  /// Creates a probe that looks for [outputPath] (relative to the project root).
  const IoOutputProbeService({this.outputPath = 'build/whisker_standup.mp4'});

  @override
  final String outputPath;

  @override
  Future<RenderOutput?> probe() async {
    final file = File(outputPath);
    if (!file.existsSync()) return null;
    return RenderOutput(path: outputPath, bytes: await file.length());
  }
}

/// The injected probe service, overridden with a fake in tests.
final Provider<OutputProbeService> outputProbeServiceProvider = Provider<OutputProbeService>(
  (ref) => const IoOutputProbeService(),
);
