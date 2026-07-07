// fluvie:large-file-ok: the MediaResolver facade; the logic lives in its five sibling parts
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluvie/src/captions/parse/srt_parser.dart';
import 'package:fluvie/src/captions/parse/vtt_parser.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/captions/caption_word.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/clip_frame_preparer.dart';
import 'package:fluvie/src/core/contracts/disposable_resolver.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/clip_source_kind.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/runtime/clip_resolve_cache.dart';
import 'package:fluvie/src/media/runtime/image_resolve_cache.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/encoding/frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';

part 'media_repository_audio.dart';
part 'media_repository_captions.dart';
part 'media_repository_clip.dart';
part 'media_repository_core.dart';
part 'media_repository_snapshot.dart';

/// The real [MediaResolver]: resolves declared media in a single pre-pass
/// before the frame loop, then serves it synchronously during the loop.
///
/// [preResolveAll] does the image IO
/// (load via [MediaBytesLoader], content-hash with the in-house fnv1a64Hex,
/// decode to a `ui.Image`); [preResolveClip] probes and extracts clip frames;
/// the snapshot, audio, reactive, and caption pre-passes live in the sibling
/// parts. Each pass is idempotent, and every read accessor is a pure synchronous
/// lookup, so no frame ever awaits media.
final class MediaRepository
    with ImageResolveCache, ClipResolveCache
    implements MediaResolver, DisposableResolver, ClipFramePreparer {
  /// Creates a repository over the byte [loader], with the [probeService] and
  /// [frameExtractor] the clip path needs (`null` until a clip is resolved).
  ///
  /// Pass a [clipFrameStore] to stream clip frames through it (decoding only a
  /// bounded window during the loop); leave it null to decode every clip frame
  /// up front. The capture loop drives the streaming window through
  /// [prepareClipFrames]; a null store makes that a no-op.
  MediaRepository({
    required this.loader,
    this.probeService,
    this.frameExtractor,
    this.clipFrameStore,
  });

  /// The per-kind byte source feeding the cache.
  @override
  final MediaBytesLoader loader;

  /// The on-disk store clip frames stream through, or null to decode every clip
  /// frame up front (overrides the cache's null default).
  @override
  final ClipFrameStore? clipFrameStore;

  @override
  Future<void> prepareClipFrames(int compFrame) => prepareClipFramesForComposition(compFrame);

  /// Probes clip sources for their fps/dimensions; required to resolve clips.
  final VideoProbeService? probeService;

  /// Extracts clip frames; required to resolve clips.
  final FrameExtractionService? frameExtractor;

  /// Local file paths the clip source was materialized to (the probe and the
  /// frame extractor both read by path). The metadata and frame caches live in
  /// the shared [ClipResolveCache].
  final Map<MediaSource, String> _clipPaths = {};

  /// Temp directories staged for materialized audio and clip source files, so
  /// [dispose] can delete them (each holds one written media file).
  final Set<Directory> _stagedDirs = {};

  // Audio, reactive, snapshot, and caption caches keyed by source value: the
  // encoder `-i`s the materialized audio, `Trigger.beat` reads the grid, the
  // ReactiveScope the table, paint the snapshot raster (by content-hash
  // [cacheKey]), and the caption layer the parsed cues. All are precomputed
  // before frame 0, so no frame ever awaits any of them.
  final Map<AudioSource, String> _audioPaths = {};
  final Map<AudioSource, BeatGrid> _beatGrids = {};
  final Map<AudioSource, BandTable> _bandTables = {};
  final Map<String, ui.Image> _snapshots = {};
  final Map<CaptionSource, List<CaptionCue>> _captionCues = {};

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async {
    await _resolveAll(sources);
    markResolved();
  }

  @override
  ResolvedMedia resolvedFor(MediaSource source) => _require(
    resolved,
    source,
    'resolvedFor',
    'resolved media',
    'Was it included in the collect pass before preResolveAll?',
  );

  @override
  ui.Image decodedImageFor(MediaSource source) => _require(
    decoded,
    source,
    'decodedImageFor',
    'decoded image',
    'Was it included in the collect pass before preResolveAll?',
  );

  @override
  Future<ClipMetadata> probeClip(MediaSource source) => resolveClipMeta(source);

  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    await resolveClipFrames(source, sourceFrames);
    markResolved();
  }

  @override
  ClipMetadata clipMetadataFor(MediaSource source) => clipMetadataLookup(source);

  @override
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame) =>
      decodedClipFrameLookup(source, sourceFrame);

  @override
  Future<ClipMetadata> probeClipSource(MediaSource source) => _probeClipSource(source);

  @override
  Future<Map<int, RawFrame>> extractClipFrames(
    MediaSource source,
    List<int> sourceFrames,
    ClipMetadata meta,
  ) => _extractClipFrames(source, sourceFrames, meta);

  @override
  Future<void> preResolveSnapshots(
    Iterable<SnapshotSource> sources,
    SnapshotService service,
  ) async {
    await _resolveSnapshots(sources, service);
    markResolved();
  }

  @override
  ui.Image decodedSnapshotFor(SnapshotSource source) => _decodedSnapshot(source);

  @override
  Future<void> preResolveAudio(Iterable<AudioSource> sources) async {
    await _resolveAudio(sources);
    markResolved();
  }

  @override
  String materializedAudioPathFor(AudioSource source) => _require(
    _audioPaths,
    source,
    'materializedAudioPathFor',
    'materialized audio',
    'Was it included in the collect pass before preResolveAudio?',
  );

  @override
  Future<void> preResolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  }) async {
    await _resolveReactive(
      sources,
      beatDetector: beatDetector,
      analyzer: analyzer,
      fps: fps,
      totalFrames: totalFrames,
    );
    markResolved();
  }

  @override
  BeatGrid beatGridFor(AudioSource source) => _require(
    _beatGrids,
    source,
    'beatGridFor',
    'beat grid',
    'Was it included in the collect pass before preResolveReactive?',
  );

  @override
  BandTable bandTableFor(AudioSource source) => _require(
    _bandTables,
    source,
    'bandTableFor',
    'band table',
    'Was it included in the collect pass before preResolveReactive?',
  );

  @override
  Future<void> preResolveCaptions(CaptionSource source) async {
    await _resolveCaptions(source);
    markResolved();
  }

  @override
  List<CaptionCue> cuesFor(CaptionSource source) => _require(
    _captionCues,
    source,
    'cuesFor',
    'parsed captions',
    'Was it included in the collect pass before preResolveCaptions?',
  );

  @override
  void dispose() {
    disposeCachedImages();
    disposeClipFrames();
    // Delete the on-disk clip-frame store in the background (it can hold many
    // frame files); the staged source dirs hold one small file each, so delete
    // them synchronously and tolerate a dir that is already gone.
    unawaited(clipFrameStore?.dispose() ?? Future<void>.value());
    for (final dir in _stagedDirs) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort: an already-removed or locked temp dir is not fatal.
      }
    }
    _stagedDirs.clear();
    for (final image in _snapshots.values) {
      image.dispose();
    }
    _snapshots.clear();
  }
}
