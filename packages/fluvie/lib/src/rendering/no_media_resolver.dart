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

// The `mediaResolverProvider` default is a real `MediaRepository`. It lives in
// the `media/` layer (which may import the byte loader); `rendering/` cannot
// import `media/` without inverting the layering, so it is re-exported here to
// keep the established public entry point stable.
export 'package:fluvie/src/media/media_resolver_provider.dart'
    show
        assetBundleProvider,
        mediaBytesLoaderProvider,
        mediaResolverProvider,
        networkAllowlistProvider;

/// The media-less [MediaResolver]: valid only for compositions that declare no
/// media at all.
///
/// Resolving an empty source list succeeds (there is nothing to do); any
/// actual media source is a typed failure pointing at the `MediaRepository`,
/// the real resolver wired as the `mediaResolverProvider` default. This stays
/// exported and is the documented choice when a composition is deliberately
/// media-free.
final class NoMediaResolver implements MediaResolver {
  /// Creates the resolver; it is stateless and const.
  const NoMediaResolver();

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async {
    if (sources.isNotEmpty) {
      throw FluvieRenderException(
        'NoMediaResolver cannot resolve media (got ${sources.length} source(s), '
        'first: "${sources.first}"). Wire a MediaRepository through '
        'mediaResolverProvider to render media, or keep this resolver for '
        'media-less compositions.',
      );
    }
  }

  @override
  ResolvedMedia resolvedFor(MediaSource source) => throw FluvieRenderException(
    'NoMediaResolver has no media for "$source". Wire a MediaRepository '
    'through mediaResolverProvider to render media.',
  );

  @override
  ui.Image decodedImageFor(MediaSource source) => throw FluvieRenderException(
    'NoMediaResolver has no decoded image for "$source". Wire a '
    'MediaRepository through mediaResolverProvider to render media.',
  );

  @override
  Future<ClipMetadata> probeClip(MediaSource source) async => throw FluvieRenderException(
    'NoMediaResolver cannot probe clip "$source". Wire a MediaRepository '
    'through mediaResolverProvider to render clips.',
  );

  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    throw FluvieRenderException(
      'NoMediaResolver cannot resolve clip "$source". Wire a MediaRepository '
      'through mediaResolverProvider to render clips.',
    );
  }

  @override
  ClipMetadata clipMetadataFor(MediaSource source) => throw FluvieRenderException(
    'NoMediaResolver has no clip metadata for "$source". Wire a '
    'MediaRepository through mediaResolverProvider to render clips.',
  );

  @override
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame) => throw FluvieRenderException(
    'NoMediaResolver has no clip frame $sourceFrame for "$source". Wire a '
    'MediaRepository through mediaResolverProvider to render clips.',
  );

  @override
  Future<void> preResolveSnapshots(
    Iterable<SnapshotSource> sources,
    SnapshotService service,
  ) async {
    if (sources.isNotEmpty) {
      throw FluvieRenderException(
        'NoMediaResolver cannot resolve snapshots (got ${sources.length} '
        'source(s), first: "${sources.first}"). Wire a MediaRepository through '
        'mediaResolverProvider to render Mermaid/WebView/Html, or keep this '
        'resolver for snapshot-less compositions.',
      );
    }
  }

  @override
  ui.Image decodedSnapshotFor(SnapshotSource source) => throw FluvieRenderException(
    'NoMediaResolver has no decoded snapshot for "$source". Wire a '
    'MediaRepository through mediaResolverProvider to render snapshots.',
  );

  @override
  Future<void> preResolveAudio(Iterable<AudioSource> sources) async {
    if (sources.isNotEmpty) {
      throw FluvieRenderException(
        'NoMediaResolver cannot resolve audio (got ${sources.length} source(s), '
        'first: "${sources.first}"). Wire a MediaRepository through '
        'mediaResolverProvider to render audio, or keep this resolver for '
        'silent compositions.',
      );
    }
  }

  @override
  String materializedAudioPathFor(AudioSource source) => throw FluvieRenderException(
    'NoMediaResolver has no materialized audio for "$source". Wire a '
    'MediaRepository through mediaResolverProvider to render audio.',
  );

  @override
  Future<void> preResolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  }) async {
    if (sources.isNotEmpty) {
      throw FluvieRenderException(
        'NoMediaResolver cannot analyse audio (got ${sources.length} source(s), '
        'first: "${sources.first}"). Wire a MediaRepository through '
        'mediaResolverProvider for beat-reactive and spectrum-reactive '
        'animations, or keep this resolver for non-reactive compositions.',
      );
    }
  }

  @override
  BeatGrid beatGridFor(AudioSource source) => throw FluvieRenderException(
    'NoMediaResolver has no beat grid for "$source". Wire a MediaRepository '
    'through mediaResolverProvider for beat-reactive animations.',
  );

  @override
  BandTable bandTableFor(AudioSource source) => throw FluvieRenderException(
    'NoMediaResolver has no band table for "$source". Wire a MediaRepository '
    'through mediaResolverProvider for spectrum-reactive animations.',
  );

  @override
  Future<void> preResolveCaptions(CaptionSource source) async {
    throw FluvieRenderException(
      'NoMediaResolver cannot resolve captions ("$source"). Wire a '
      'MediaRepository through mediaResolverProvider to render captions, or keep '
      'this resolver for caption-less compositions.',
    );
  }

  @override
  List<CaptionCue> cuesFor(CaptionSource source) => throw FluvieRenderException(
    'NoMediaResolver has no parsed captions for "$source". Wire a '
    'MediaRepository through mediaResolverProvider to render captions.',
  );
}
