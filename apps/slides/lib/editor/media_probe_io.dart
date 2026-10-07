import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:slides/editor/media_metadata.dart';

/// Best-effort import metadata. Failure leaves the asset reusable; the source
/// monitor explicitly states when timed media cannot yet be marked.
Future<MediaMetadata> probeImportedMedia({
  required String? path,
  required Uint8List? bytes,
  required bool video,
  required bool audio,
  Future<Process> Function(String executable, List<String> arguments)? startProcess,
  Duration timeout = const Duration(seconds: 20),
}) async {
  try {
    if (!video && !audio) {
      final data = bytes ?? (path == null ? null : await File(path).readAsBytes());
      if (data == null) return const MediaMetadata();
      final buffer = await ui.ImmutableBuffer.fromUint8List(data);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          return MediaMetadata(width: descriptor.width, height: descriptor.height);
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    }
    if (path == null || !File(path).existsSync()) return const MediaMetadata();
    final process = await (startProcess ?? Process.start)('ffprobe', [
      '-v',
      'error',
      '-show_streams',
      '-show_format',
      '-of',
      'json',
      path,
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.drain<void>();
    final code = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    await errors;
    if (code != 0) return const MediaMetadata();
    return MediaMetadata.fromProbe(jsonDecode(await output) as Map<String, Object?>, audio: audio);
  } on Object {
    return const MediaMetadata();
  }
}
