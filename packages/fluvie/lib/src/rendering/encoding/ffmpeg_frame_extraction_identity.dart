part of 'ffmpeg_frame_extraction_service.dart';

// Build lookup and streaming executable hashes are shared by native extractors.
// Metadata memoization assumes executable changes update size or filesystem times.
final Map<String, Future<String?>> _ffmpegExtractionIdentities = {};

Future<String?> _frameExtractionCacheIdentity(FfmpegFrameExtractionService service) async {
  final explicit = service._cacheIdentity;
  if (explicit != null) return explicit.trim().isEmpty ? null : explicit;
  if (service._runner is! IoProcessRunner) return null;
  return _nativeFrameExtractionIdentity(service.binaryPath);
}

Future<String?> _nativeFrameExtractionIdentity(String executable) async {
  try {
    final candidate = _executableFile(executable);
    if (candidate == null) return null;
    final file = File(await candidate.resolveSymbolicLinks());
    final metadata = file.statSync();
    if (metadata.type != FileSystemEntityType.file) return null;
    final key = _executableStamp(file.path, metadata);
    final existing = _ffmpegExtractionIdentities.remove(key);
    if (existing != null) {
      _ffmpegExtractionIdentities[key] = existing;
      return await existing;
    }
    final identity = _readExtractionBuild(file, key);
    _ffmpegExtractionIdentities[key] = identity;
    if (_ffmpegExtractionIdentities.length > 16) {
      _ffmpegExtractionIdentities.remove(_ffmpegExtractionIdentities.keys.first)?.ignore();
    }
    return await identity;
  } on FileSystemException {
    return null;
  }
}

Future<String?> _readExtractionBuild(File executable, String stamp) async {
  final tools = FfmpegMediaTools(ffmpegPath: executable.path, timeout: const Duration(seconds: 10));
  try {
    final binaryHash = await sha256.bind(executable.openRead()).first;
    final version = await tools.run(executable.path, ['-version']);
    if (version.exitCode != 0 || !version.stdout.startsWith('ffmpeg version ')) return null;
    if (_executableStamp(executable.path, executable.statSync()) != stamp) return null;
    final buildHash = sha256.convert(utf8.encode(version.stdout));
    return 'ffmpeg-rgba-v1:$binaryHash:$buildHash';
  } on Exception {
    // Cache provenance is optional; extraction still reports actual media errors.
    return null;
  } finally {
    await tools.closeAsync();
  }
}

String _executableStamp(String path, FileStat stat) => jsonEncode([
  path,
  stat.size,
  stat.modified.microsecondsSinceEpoch,
  stat.changed.microsecondsSinceEpoch,
  stat.mode,
]);

File? _executableFile(String executable) {
  if (executable.contains('/') || executable.contains(r'\')) return File(executable).absolute;
  final suffixes = Platform.isWindows
      ? ['', ...(Platform.environment['PATHEXT'] ?? '.EXE;.BAT;.CMD').split(';')]
      : [''];
  for (final directory in (Platform.environment['PATH'] ?? '').split(
    Platform.isWindows ? ';' : ':',
  )) {
    for (final suffix in suffixes) {
      final file = File(
        '${directory.isEmpty ? Directory.current.path : directory}${Platform.pathSeparator}$executable$suffix',
      );
      if (file.existsSync()) return file;
    }
  }
  return null;
}
