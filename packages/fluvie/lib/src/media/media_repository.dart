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
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart';
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
/// (load via [MediaBytesLoader], content-hash with the in-house [fnv1a64Hex],
/// decode to a `ui.Image`); [preResolveClip] probes and extracts clip frames;
/// the snapshot, audio, reactive, and caption pre-passes live in the sibling
/// parts. Each pass is idempotent, and every read accessor is a pure synchronous
/// lookup, so no frame ever awaits media.
final class MediaRepository implements MediaResolver {
  /// Creates a repository over the byte [loader], with the [probeService] and
  /// [frameExtractor] the clip path needs (`null` until a clip is resolved).
  MediaRepository({required this.loader, this.probeService, this.frameExtractor});

  /// The per-kind byte source feeding the cache.
  final MediaBytesLoader loader;

  /// Probes clip sources for their fps/dimensions; required to resolve clips.
  final VideoProbeService? probeService;

  /// Extracts clip frames; required to resolve clips.
  final FrameExtractionService? frameExtractor;

  final Map<MediaSource, ResolvedMedia> _resolved = {};
  final Map<MediaSource, ui.Image> _decoded = {};
  final Map<MediaSource, ClipMetadata> _clipMeta = {};
  final Map<MediaSource, String> _clipPaths = {};
  final Map<MediaSource, Map<int, ui.Image>> _clipFrames = {};

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
  bool _preResolved = false;

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async {
    await _resolveAll(sources);
    _preResolved = true;
  }

  @override
  ResolvedMedia resolvedFor(MediaSource source) => _require(
    _resolved,
    source,
    'resolvedFor',
    'resolved media',
    'Was it included in the collect pass before preResolveAll?',
  );

  @override
  ui.Image decodedImageFor(MediaSource source) => _require(
    _decoded,
    source,
    'decodedImageFor',
    'decoded image',
    'Was it included in the collect pass before preResolveAll?',
  );

  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    await _resolveClip(source, sourceFrames);
    _preResolved = true;
  }

  @override
  ClipMetadata clipMetadataFor(MediaSource source) => _require(
    _clipMeta,
    source,
    'clipMetadataFor',
    'clip metadata',
    'Was it pre-resolved with preResolveClip before the frame loop?',
  );

  @override
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame) =>
      _decodedClipFrame(source, sourceFrame);

  @override
  Future<void> preResolveSnapshots(
    Iterable<SnapshotSource> sources,
    SnapshotService service,
  ) async {
    await _resolveSnapshots(sources, service);
    _preResolved = true;
  }

  @override
  ui.Image decodedSnapshotFor(SnapshotSource source) => _decodedSnapshot(source);

  @override
  Future<void> preResolveAudio(Iterable<AudioSource> sources) async {
    await _resolveAudio(sources);
    _preResolved = true;
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
    _preResolved = true;
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
    _preResolved = true;
  }

  @override
  List<CaptionCue> cuesFor(CaptionSource source) => _require(
    _captionCues,
    source,
    'cuesFor',
    'parsed captions',
    'Was it included in the collect pass before preResolveCaptions?',
  );
}
