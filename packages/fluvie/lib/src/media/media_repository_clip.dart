part of 'media_repository.dart';

/// The `dart:io` half of [MediaRepository]'s clip path: materialize the source
/// to a local file the probe and extractor can read by path. The cache, frame
/// diffing, decode, and lookups live in the shared [ClipResolveCache] mixin;
/// `probeClipSource` and `extractClipFrames` (in the main class) call this.
extension _ClipResolution on MediaRepository {
  /// Materializes [source], probes it for [ClipMetadata], and converts the
  /// probe result (ffprobe fps from frames over duration). The [ClipResolveCache]
  /// caches the result, so this runs once per source.
  Future<ClipMetadata> _probeClipSource(MediaSource source) async {
    final probe = probeService;
    if (probe == null) {
      throw FluvieRenderException(
        'MediaRepository cannot probe clip "$source" without a VideoProbeService. '
        'Wire it through the providers.',
      );
    }
    final path = await _materializeClip(source);
    final result = await probe.probe(path);
    final fps = result.durationSeconds > 0
        ? result.nbFrames / result.durationSeconds
        : result.nbFrames.toDouble();
    return (
      fps: fps,
      frameCount: result.nbFrames,
      width: result.width,
      height: result.height,
      hasAudio: result.hasAudio,
    );
  }

  /// Extracts the [sourceFrames] of the already-materialized [source] at the clip
  /// [meta] dimensions through the ffmpeg [FrameExtractionService].
  Future<Map<int, RawFrame>> _extractClipFrames(
    MediaSource source,
    List<int> sourceFrames,
    ClipMetadata meta,
  ) async {
    final extractor = frameExtractor;
    if (extractor == null) {
      throw FluvieRenderException(
        'MediaRepository cannot resolve clip "$source" without a '
        'FrameExtractionService. Wire it through the providers.',
      );
    }
    return extractor.extractFrames(
      Uri.file(_clipPaths[source]!),
      sourceFrames,
      width: meta.width,
      height: meta.height,
    );
  }

  /// Loads the clip bytes once and writes them to a temp file the probe and
  /// extractor can read by path; cached per source.
  Future<String> _materializeClip(MediaSource source) async {
    final existing = _clipPaths[source];
    if (existing != null) return existing;
    final bytes = await loader.load(source);
    final dir = await Directory.systemTemp.createTemp('fluvie_clip_src_');
    _stagedDirs.add(dir);
    final file = File('${dir.path}/clip.mp4');
    await file.writeAsBytes(bytes);
    return _clipPaths[source] = file.path;
  }
}

/// A [ClipFrameStore] that keeps each extracted clip frame in its own file
/// under a temp directory — the on-device/desktop store, so a clip's frames
/// live on disk instead of the heap and the resolver only ever decodes the
/// small window the current composition frame needs.
///
/// The directory is created lazily on the first [put] (a render with no clip
/// never makes one) and removed wholesale by [dispose]. Frames are addressed by
/// the resolver's opaque per-clip key plus the source-frame index; the keys are
/// generated, never attacker-controlled, so the paths are safe.
final class FileClipFrameStore implements ClipFrameStore {
  Directory? _dir;

  Future<Directory> _ensureDir() async =>
      _dir ??= await Directory.systemTemp.createTemp('fluvie_clip_frames_');

  @override
  Future<void> put(String clipKey, int frame, Uint8List rgba) async {
    final dir = await _ensureDir();
    final file = File('${dir.path}/$clipKey/$frame.rgba');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(rgba);
  }

  @override
  Future<Uint8List?> get(String clipKey, int frame) async {
    final dir = _dir;
    if (dir == null) return null;
    final file = File('${dir.path}/$clipKey/$frame.rgba');
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> dispose() async {
    final dir = _dir;
    _dir = null;
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}
