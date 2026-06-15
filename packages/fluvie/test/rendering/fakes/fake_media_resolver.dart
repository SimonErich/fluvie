import 'dart:ui' as ui;

import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';

/// Canned [MediaResolver] for tests: serves a fixed
/// `MediaSource -> ResolvedMedia` map (plus optional pre-decoded images) and
/// **enforces the pass ordering** — [resolvedFor]/[decodedImageFor] before
/// [preResolveAll] is a [StateError], exactly the bug the contract exists to
/// prevent.
///
/// Demoted to a test fixture once the real `MediaRepository` became the
/// `mediaResolverProvider` default (the Seams Ledger `MediaResolver` row).
final class FakeMediaResolver implements MediaResolver {
  /// Creates a resolver serving exactly [canned], with optional pre-decoded
  /// [images] for the image sources, plus canned clip [metadata] and
  /// [clipFrames] (`source -> frame -> image`) for the clip sources.
  FakeMediaResolver(
    Map<MediaSource, ResolvedMedia> canned, {
    Map<MediaSource, ui.Image> images = const {},
    Map<MediaSource, ClipMetadata> metadata = const {},
    Map<MediaSource, Map<int, ui.Image>> clipFrames = const {},
    Map<SnapshotSource, ui.Image> snapshots = const {},
    Map<AudioSource, String> audioPaths = const {},
    Map<AudioSource, BeatGrid> beatGrids = const {},
    Map<AudioSource, BandTable> bandTables = const {},
    Map<CaptionSource, List<CaptionCue>> captionCues = const {},
  }) : _canned = Map.of(canned),
       _images = Map.of(images),
       _metadata = Map.of(metadata),
       _snapshots = Map.of(snapshots),
       _audioPaths = Map.of(audioPaths),
       _beatGrids = Map.of(beatGrids),
       _bandTables = Map.of(bandTables),
       _captionCues = Map.of(captionCues),
       _clipFrames = {
         for (final entry in clipFrames.entries) entry.key: Map.of(entry.value),
       };

  final Map<MediaSource, ResolvedMedia> _canned;
  final Map<MediaSource, ui.Image> _images;
  final Map<MediaSource, ClipMetadata> _metadata;
  final Map<MediaSource, Map<int, ui.Image>> _clipFrames;
  final Map<SnapshotSource, ui.Image> _snapshots;
  final Map<AudioSource, String> _audioPaths;
  final Map<AudioSource, BeatGrid> _beatGrids;
  final Map<AudioSource, BandTable> _bandTables;
  final Map<CaptionSource, List<CaptionCue>> _captionCues;
  bool _preResolved = false;

  /// Whether [preResolveAll] has completed.
  bool get preResolved => _preResolved;

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async {
    for (final source in sources) {
      if (!_canned.containsKey(source)) {
        throw FluvieRenderException('FakeMediaResolver has no canned media for "$source".');
      }
    }
    _preResolved = true;
  }

  @override
  ResolvedMedia resolvedFor(MediaSource source) {
    _assertResolved('resolvedFor');
    final media = _canned[source];
    if (media == null) {
      throw FluvieRenderException('FakeMediaResolver has no canned media for "$source".');
    }
    return media;
  }

  @override
  ui.Image decodedImageFor(MediaSource source) {
    _assertResolved('decodedImageFor');
    final image = _images[source];
    if (image == null) {
      throw FluvieRenderException('FakeMediaResolver has no decoded image for "$source".');
    }
    return image;
  }

  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    if (!_metadata.containsKey(source)) {
      throw FluvieRenderException('FakeMediaResolver has no canned clip metadata for "$source".');
    }
    final frames = _clipFrames[source] ?? const {};
    for (final frame in sourceFrames) {
      if (!frames.containsKey(frame)) {
        throw FluvieRenderException(
          'FakeMediaResolver has no canned clip frame $frame for "$source".',
        );
      }
    }
    _preResolved = true;
  }

  @override
  ClipMetadata clipMetadataFor(MediaSource source) {
    _assertResolved('clipMetadataFor');
    final metadata = _metadata[source];
    if (metadata == null) {
      throw FluvieRenderException('FakeMediaResolver has no canned clip metadata for "$source".');
    }
    return metadata;
  }

  @override
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame) {
    _assertResolved('decodedClipFrame');
    final image = _clipFrames[source]?[sourceFrame];
    if (image == null) {
      throw FluvieRenderException(
        'FakeMediaResolver has no canned clip frame $sourceFrame for "$source".',
      );
    }
    return image;
  }

  @override
  Future<void> preResolveSnapshots(
    Iterable<SnapshotSource> sources,
    SnapshotService service,
  ) async {
    for (final source in sources) {
      if (!_snapshots.containsKey(source)) {
        throw FluvieRenderException('FakeMediaResolver has no canned snapshot for "$source".');
      }
    }
    _preResolved = true;
  }

  @override
  ui.Image decodedSnapshotFor(SnapshotSource source) {
    _assertResolved('decodedSnapshotFor');
    final image = _snapshots[source];
    if (image == null) {
      throw FluvieRenderException('FakeMediaResolver has no canned snapshot for "$source".');
    }
    return image;
  }

  @override
  Future<void> preResolveAudio(Iterable<AudioSource> sources) async {
    for (final source in sources) {
      if (!_audioPaths.containsKey(source)) {
        throw FluvieRenderException('FakeMediaResolver has no canned audio for "$source".');
      }
    }
    _preResolved = true;
  }

  @override
  String materializedAudioPathFor(AudioSource source) {
    _assertResolved('materializedAudioPathFor');
    final path = _audioPaths[source];
    if (path == null) {
      throw FluvieRenderException('FakeMediaResolver has no materialized audio for "$source".');
    }
    return path;
  }

  @override
  Future<void> preResolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  }) async {
    for (final source in sources) {
      if (!_beatGrids.containsKey(source) || !_bandTables.containsKey(source)) {
        throw FluvieRenderException(
          'FakeMediaResolver has no canned reactive analysis for "$source".',
        );
      }
    }
    _preResolved = true;
  }

  @override
  BeatGrid beatGridFor(AudioSource source) {
    _assertResolved('beatGridFor');
    final grid = _beatGrids[source];
    if (grid == null) {
      throw FluvieRenderException('FakeMediaResolver has no canned beat grid for "$source".');
    }
    return grid;
  }

  @override
  BandTable bandTableFor(AudioSource source) {
    _assertResolved('bandTableFor');
    final table = _bandTables[source];
    if (table == null) {
      throw FluvieRenderException('FakeMediaResolver has no canned band table for "$source".');
    }
    return table;
  }

  @override
  Future<void> preResolveCaptions(CaptionSource source) async {
    if (!_captionCues.containsKey(source)) {
      throw FluvieRenderException('FakeMediaResolver has no canned captions for "$source".');
    }
    _preResolved = true;
  }

  @override
  List<CaptionCue> cuesFor(CaptionSource source) {
    _assertResolved('cuesFor');
    final cues = _captionCues[source];
    if (cues == null) {
      throw FluvieRenderException('FakeMediaResolver has no canned captions for "$source".');
    }
    return cues;
  }

  void _assertResolved(String member) {
    if (!_preResolved) {
      throw StateError(
        '$member was called before preResolveAll completed. The pre-resolve '
        'pass must run before the frame loop (no async media mid-frame).',
      );
    }
  }
}
