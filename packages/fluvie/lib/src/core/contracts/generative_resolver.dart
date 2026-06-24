import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';

/// The probed facts about a produced generative asset the render needs: its
/// `duration` (audio/video), whether a video carries an embedded audio track
/// (`hasAudio`), and its pixel size when known.
typedef GeneratedAssetMeta = ({Duration? duration, bool hasAudio, int? width, int? height});

/// Coarse progress for one generative asset during the prerender pass, surfaced
/// to the render's progress callback: which asset (`index` of `total`), its
/// `providerId`, and a human `stage` (for example `generating`, `downloading`,
/// `cached`).
typedef GenerativeProgress = ({int index, int total, String providerId, String stage});

/// Produces every declared generative source before the media pre-pass and
/// serves the resolved local source **synchronously** afterwards.
///
/// The shape *is* the ordering guarantee, exactly like `MediaResolver`: all
/// generation (API calls, polling, downloads, caching) happens in [generateAll]
/// before the first frame is pumped, and [mediaFor]/[audioFor]/[metaFor] are
/// pure synchronous lookups. A produced asset is a plain file-backed
/// `MediaSource`/`AudioSource` by the time the media collectors read it, so the
/// existing pre-resolve, clip, and audio-mix machinery handles it unchanged.
///
/// The library default is `NoGenerativeResolver` (a no-op for an empty set, a
/// clear error otherwise); the real implementation lives in `fluvie_ai`.
/// `MediaResolver`, `NoGenerativeResolver` and `fluvie_ai` are named in prose,
/// not as doc links, because they live in layers above `core`.
abstract interface class GenerativeResolver {
  /// Produces every source in [sources] (cache hit or generate) so that
  /// [mediaFor], [audioFor], and [metaFor] can answer synchronously afterwards.
  ///
  /// Runs before the first frame and is idempotent: producing the same source
  /// (by [GenerativeSource.cacheKey]) twice does the work once. Reports coarse
  /// progress through [onProgress]. Throws a `FluvieGenerativeException` when a
  /// source cannot be produced (provider error, offline cache miss, or budget).
  Future<void> generateAll(
    Iterable<GenerativeSource> sources, {
    void Function(GenerativeProgress progress)? onProgress,
  });

  /// The resolved file-backed [MediaSource] for a produced visual [source]
  /// (image or video) — synchronous by contract.
  ///
  /// Only valid after [generateAll] for a visual source; implementations throw
  /// on an unresolved or non-visual source.
  MediaSource mediaFor(GenerativeSource source);

  /// The resolved file-backed [AudioSource] for a produced audio [source]
  /// (music, speech, or sound effect) — synchronous by contract.
  ///
  /// Only valid after [generateAll] for an audio source; implementations throw
  /// on an unresolved or non-audio source.
  AudioSource audioFor(GenerativeSource source);

  /// The probed [GeneratedAssetMeta] for produced [source] — synchronous by
  /// contract, so the timeline can read a clip's duration and audio flag.
  ///
  /// Only valid after [generateAll] for [source]; implementations throw on an
  /// unresolved source.
  GeneratedAssetMeta metaFor(GenerativeSource source);
}
