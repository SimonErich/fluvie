import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
// The caption value types (`CaptionSource`, `CaptionCue`) the caption pre-pass
// keys on are referenced here so the render shell can read cues through the
// `MediaResolver` interface. They are pure data carrying only Dart-core and
// `core` types, so this stays a forward dependency mediated by the interface,
// the layering law's escape hatch — no `core` impl reaches into the captions
// layer.
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';

/// One pre-resolved media asset: its raw `bytes` and the `contentHash` that
/// keys caches and render digests.
typedef ResolvedMedia = ({Uint8List bytes, String contentHash});

/// The probed facts a `Clip` needs to resample a source video deterministically
/// — its frame rate, frame count, and pixel dimensions.
///
/// The render layer's `VideoProbeService` produces a richer report; the
/// resolver hands the elements only the fields the resampler reads, in a
/// `core`-resident value so `Clip` never imports the render layer.
typedef ClipMetadata = ({double fps, int frameCount, int width, int height});

/// Pre-resolves every media source before the frame loop and serves the
/// resolved bytes (and decoded images) **synchronously** during it.
///
/// The shape *is* the determinism guarantee: all IO (downloads, disk reads,
/// decodes) happens in [preResolveAll] before the first frame is pumped, and
/// both [resolvedFor] and [decodedImageFor] are pure synchronous lookups — no
/// frame can ever await media. The contract keys on [MediaSource] (not `Uri`)
/// because `asset`/`memory` sources have no honest URL. The real resolver (the
/// `MediaRepository`) is the library default; `NoMediaResolver` stays exported
/// as the media-less choice and tests run against a canned fake.
abstract interface class MediaResolver {
  /// Resolves every source in [sources] (download, read, decode) so that
  /// [resolvedFor] and [decodedImageFor] can answer synchronously during the
  /// frame loop.
  ///
  /// Runs before the first frame and is idempotent: resolving the same source
  /// twice does the work once. Throws a `FluvieRenderException` when a source
  /// cannot be resolved.
  Future<void> preResolveAll(Iterable<MediaSource> sources);

  /// The pre-resolved bytes and content hash for [source] — synchronous by
  /// contract.
  ///
  /// Only valid after [preResolveAll] completed; implementations throw on an
  /// unresolved source instead of returning partial data.
  ResolvedMedia resolvedFor(MediaSource source);

  /// The pre-decoded image for [source] — synchronous by contract, so paint
  /// can hand it straight to a `RawImage` with no async-in-frame.
  ///
  /// Only valid after [preResolveAll] completed for an *image* source;
  /// implementations throw on an unresolved or non-image source.
  ui.Image decodedImageFor(MediaSource source);

  /// Probes clip [source] for its [ClipMetadata] (fps, frame count, size) and
  /// caches it, so the render's clip pre-pass can plan which source frames to
  /// extract before calling [preResolveClip].
  ///
  /// Idempotent: a probed source is served from cache. Throws a
  /// `FluvieRenderException` when the source cannot be probed.
  Future<ClipMetadata> probeClip(MediaSource source);

  /// Probes [source] and extracts every source frame in [sourceFrames],
  /// decoding each to a `ui.Image` cached by `(source, frame)` so paint can
  /// read it synchronously.
  ///
  /// Runs in the pre-resolve pass before the frame loop and is idempotent: a
  /// frame already extracted is skipped. Throws a `FluvieRenderException` when
  /// the source cannot be probed or a frame cannot be extracted.
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames);

  /// The probed [ClipMetadata] of clip [source] — synchronous by contract,
  /// so the resampler can read its source fps and frame count during the
  /// frame loop.
  ///
  /// Only valid after [preResolveClip] completed for [source]; implementations
  /// throw on an un-probed source.
  ClipMetadata clipMetadataFor(MediaSource source);

  /// The pre-decoded image of clip [source] at [sourceFrame] — synchronous by
  /// contract, so paint hands it straight to a `RawImage`.
  ///
  /// Only valid after [preResolveClip] extracted [sourceFrame] for [source];
  /// implementations throw on an unresolved source or frame.
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame);

  /// Rasterizes every snapshot in [sources] through [service] and decodes each
  /// raster to a `ui.Image` cached by content hash, so [decodedSnapshotFor] can
  /// answer synchronously during the frame loop.
  ///
  /// Runs in the pre-resolve pass before the frame loop and is idempotent: a
  /// source already resolved is skipped (its cache entry is reused). Throws a
  /// `FluvieRenderException` when a raster cannot be decoded, and surfaces the
  /// service's `FluvieSnapshotUnavailableError` when the backend is missing.
  Future<void> preResolveSnapshots(Iterable<SnapshotSource> sources, SnapshotService service);

  /// The pre-decoded image for snapshot [source] — synchronous by contract, so
  /// paint hands it straight to a `RawImage` with no async-in-frame.
  ///
  /// Only valid after [preResolveSnapshots] completed for [source];
  /// implementations throw on an unresolved source instead of a blank frame.
  ui.Image decodedSnapshotFor(SnapshotSource source);

  /// Materializes every audio source in [sources] into a sandbox file the
  /// encoder can `-i`, validating and allowlisting each one first.
  ///
  /// Runs in the pre-resolve pass before the frame loop and is idempotent: a
  /// source already materialized is skipped. A disallowed network host is a
  /// `FluvieRenderException` naming the host, surfaced here before any fetch —
  /// audio mixing happens entirely in the encoder, never in capture, so no
  /// frame ever awaits audio. The reactive analysis the same source feeds (the
  /// beat grid and band table) is handled by [preResolveReactive].
  Future<void> preResolveAudio(Iterable<AudioSource> sources);

  /// The materialized local file path for audio [source] — synchronous by
  /// contract, so the encode-plan builder can hand it to an audio track node.
  ///
  /// Only valid after [preResolveAudio] completed for [source];
  /// implementations throw on an unresolved source naming it.
  String materializedAudioPathFor(AudioSource source);

  /// Analyses every reactive audio source in [sources] into a [BeatGrid] and a
  /// [BandTable] before the frame loop.
  ///
  /// Kept separate from [preResolveAudio] so the encoder-file-materialize
  /// concern (which the encoder `-i`s) and the reactive analysis concern (which
  /// the `ReactiveScope` and `Trigger.beat` read) stay independent. Each source
  /// is decoded once and run through [beatDetector] / [analyzer] at [fps] over
  /// [totalFrames]; the results feed [beatGridFor] / [bandTableFor]
  /// synchronously during the frame loop, so no frame ever awaits audio
  /// analysis. Idempotent: an already-analysed source is skipped. The reactive
  /// inputs are precomputed before frame 0 exactly like media.
  Future<void> preResolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  });

  /// The detected [BeatGrid] for audio [source] — synchronous by contract, so
  /// `Trigger.beat` resolves against it during timing resolution.
  ///
  /// Only valid after [preResolveReactive] completed for [source];
  /// implementations throw on an unresolved source naming it.
  BeatGrid beatGridFor(AudioSource source);

  /// The analysed [BandTable] for audio [source] — synchronous by contract, so
  /// the `ReactiveScope` can serve it down to the reactive effects.
  ///
  /// Only valid after [preResolveReactive] completed for [source];
  /// implementations throw on an unresolved source naming it.
  BandTable bandTableFor(AudioSource source);

  /// Reads and parses caption [source] into [CaptionCue]s before the frame loop,
  /// so [cuesFor] can serve them synchronously during it.
  ///
  /// An SRT/VTT source is read through the byte loader and parsed by the
  /// in-house parser; an inline source needs no IO (its words become cues
  /// directly). Idempotent: an already-parsed source is skipped. A file that
  /// cannot be read is a `FluvieRenderException`, and a malformed timecode is a
  /// `FluvieTimingError` naming the line — both surface here, in the pre-pass,
  /// so no frame ever reads or parses a caption file.
  Future<void> preResolveCaptions(CaptionSource source);

  /// The parsed [CaptionCue]s for caption [source] — synchronous by contract,
  /// so the caption layer can pick the active cue at the current frame.
  ///
  /// Only valid after [preResolveCaptions] completed for [source];
  /// implementations throw on an unresolved source naming it.
  List<CaptionCue> cuesFor(CaptionSource source);
}
