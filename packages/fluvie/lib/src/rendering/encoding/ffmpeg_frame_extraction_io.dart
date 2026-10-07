part of 'ffmpeg_frame_extraction_service.dart';

/// The typed extraction argument array — a frame select + scale filter, one
/// rawvideo frame, written to the sandbox-relative [output] file.
///
/// `-c:v` selects the decoder for the input that *follows* it, so it must
/// precede `-i` to apply to the source rather than to the output.
List<String> _args({
  required String path,
  required int frameIndex,
  required int width,
  required int height,
  required String output,
  String? decoder,
}) => [
  '-v',
  'error',
  '-nostdin',
  '-protocol_whitelist',
  'file',
  if (decoder != null) ...['-c:v', decoder],
  '-i',
  path,
  '-vf',
  'select=eq(n\\,$frameIndex),scale=$width:$height',
  '-frames:v',
  '1',
  '-f',
  'rawvideo',
  '-pix_fmt',
  'rgba',
  '-y',
  output,
];

Future<Uint8List> _readOutput(File file, Uri source, int frameIndex) async {
  if (!file.existsSync()) {
    throw FluvieRenderException(
      'FFmpeg wrote no frame file for frame $frameIndex of "$source".',
    );
  }
  return file.readAsBytes();
}

/// Maps [source] to a local file path and rejects anything that could be
/// parsed as a flag (a leading `-`) or is empty — flag-injection safety.
String _validatedPath(Uri source) {
  final path = source.isScheme('file') ? source.toFilePath() : source.toString();
  if (path.isEmpty) {
    throw ArgumentError.value(path, 'source', 'must not be empty');
  }
  if (path.startsWith('-')) {
    throw ArgumentError.value(path, 'source', 'must not start with "-" (flag injection)');
  }
  return path;
}

/// Rejects a decoder name that could be parsed as a flag or is empty — the
/// same guard [_validatedPath] applies, because the decoder reaches this
/// service as a public parameter too.
String? _validatedDecoder(String? decoder) {
  if (decoder == null) return null;
  if (decoder.isEmpty) {
    throw ArgumentError.value(decoder, 'decoder', 'must not be empty');
  }
  if (decoder.startsWith('-')) {
    throw ArgumentError.value(decoder, 'decoder', 'must not start with "-" (flag injection)');
  }
  return decoder;
}

String _tail(String stderr) => stderr.length <= FfmpegFrameExtractionService.stderrTailLength
    ? stderr
    : stderr.substring(stderr.length - FfmpegFrameExtractionService.stderrTailLength);
