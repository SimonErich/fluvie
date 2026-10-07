import 'dart:ui' as ui;

import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/clip_timeline_resolver.dart';
import 'package:fluvie/src/core/contracts/disposable_resolver.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_capability_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/clip_source_kind.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/runtime/clip_resolve_cache.dart';
import 'package:fluvie/src/media/runtime/image_resolve_cache.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

part 'web_unsupported_capabilities.dart';

/// The browser [MediaResolver]: resolves declared **image** media (asset,
/// network, memory) for in-browser rendering, with no `dart:io`, plus **clips**
/// when a [WebClipDecoder] is wired.
///
/// It shares the image cache and decode with `MediaRepository` through
/// [ImageResolveCache], and the clip cache through [ClipResolveCache]. A clip is
/// probed and frame-extracted through the injected [clipDecoder] (WebCodecs);
/// with no decoder a declared clip fails with a clear typed error. Snapshots,
/// audio, beat/spectrum reactivity, and captions are not available in the
/// browser yet, so each of those members fails with a clear typed error instead
/// of a confusing decode failure. `file://` sources fail through the byte
/// loader's web seam.
final class WebImageMediaResolver
    with ImageResolveCache, ClipResolveCache, _UnsupportedWebCapabilities
    implements MediaResolver, DisposableResolver, ClipTimelineResolver {
  /// Creates a resolver over the byte [loader], optionally with a [clipDecoder]
  /// for in-browser clip support.
  ///
  /// Pass [maxClipDecodeEdge] to decode clips at a bounded long edge. The
  /// browser resolver has no disk frame store. The shared composition session
  /// resolves frames on demand and retires its bounded scrub cache after paint;
  /// each retained full-HD RGBA frame takes approximately 8.3 MB. A live
  /// preview sets a decode-size bound; a render leaves it null.
  WebImageMediaResolver({required this.loader, this.clipDecoder, this.maxClipDecodeEdge});

  @override
  final MediaBytesLoader loader;

  /// Decodes clip frames from bytes (WebCodecs), or `null` for images only.
  final WebClipDecoder? clipDecoder;

  /// The longest side clips decode at, or null for full source resolution
  /// (overrides the cache's null default).
  @override
  final int? maxClipDecodeEdge;

  @override
  void dispose() {
    disposeCachedImages();
    disposeClipFrames();
  }

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async {
    for (final source in sources) {
      if (resolved.containsKey(source)) continue;
      final media = await loadAndCacheBytes(source);
      // A clip is content-hashed here but decoded through preResolveClip (the
      // WebCodecs path), never as an image — the same footgun guard as desktop.
      if (!isClipSource(source)) {
        decoded[source] = await decodeImageBytes('image "$source"', media.bytes);
      }
    }
    markResolved();
  }

  @override
  Future<ClipMetadata> probeClipSource(MediaSource source) async {
    final decoder = _requireDecoder(source);
    final media = resolved[source] ?? await loadAndCacheBytes(source);
    final metadata = await decoder.probe(media.bytes);
    if (decoder is WebClipTimelineDecoder) {
      final timeline = await (decoder as WebClipTimelineDecoder).probeTimeline(media.bytes);
      if (timeline != null) {
        if (timeline.frameCount != metadata.frameCount) {
          throw FluvieRenderException(
            'Clip "$source" has inconsistent decoder frame count and display timing.',
          );
        }
        clipTimelines[source] = timeline;
      }
    }
    return metadata;
  }

  @override
  MediaTimeline? clipTimelineFor(MediaSource source) => clipTimelines[source];

  @override
  Future<Map<int, RawFrame>> extractClipFrames(
    MediaSource source,
    List<int> sourceFrames,
    ClipMetadata meta,
  ) {
    final decoder = _requireDecoder(source);
    return decoder.extractFrames(
      resolved[source]!.bytes,
      sourceFrames,
      width: meta.width,
      height: meta.height,
    );
  }

  WebClipDecoder _requireDecoder(MediaSource source) {
    final decoder = clipDecoder;
    if (decoder == null) {
      throw FluvieRenderException(
        'Clip "$source" needs a WebClipDecoder to render in the browser. Wire one '
        '(for example the WebCodecs decoder from fluvie_web_encoder) into the '
        'resolver, or render the clip on the desktop/server path.',
      );
    }
    return decoder;
  }

  @override
  ResolvedMedia resolvedFor(MediaSource source) {
    assertResolved('resolvedFor');
    final media = resolved[source];
    if (media == null) {
      throw FluvieRenderException(
        'WebImageMediaResolver has no resolved media for "$source". Was it '
        'included in the collect pass before preResolveAll?',
      );
    }
    return media;
  }

  @override
  ui.Image decodedImageFor(MediaSource source) {
    assertResolved('decodedImageFor');
    final image = decoded[source];
    if (image == null) {
      throw FluvieRenderException(
        'WebImageMediaResolver has no decoded image for "$source". Was it '
        'included in the collect pass before preResolveAll?',
      );
    }
    return image;
  }

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
}
