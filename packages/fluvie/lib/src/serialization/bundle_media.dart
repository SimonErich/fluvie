import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/media/media_source.dart';

/// The materialized contents of a `.fluvie` bundle: bundle-relative values
/// (`media/<name>`) mapped to real, loadable sources.
///
/// A document saved as a bundle references its media with the `bundle` source
/// kind — `{"kind": "bundle", "value": "media/b-roll.mp4"}` — so the digest
/// stays machine-stable. The kind never reaches the engine: the loader unpacks
/// the bundle first (into memory sources on the web, into files under a
/// sandboxed temp directory on desktop), builds one `BundleMedia` from the
/// result, and puts it in scope. Building a spec that still holds a bundle
/// source with no scope set throws, naming the missing bundle context — an
/// untrusted spec cannot smuggle bytes or paths through the kind.
///
/// The scope has two shapes: [current] is the loader's session slot (element
/// builds happen across frames, so an editor or player sets it for as long as
/// its bundle document is open), and [resolve] runs one build under a scoped
/// value, restoring the previous one on exit — the `ThemeSpec.resolve`
/// pattern, for renders and tests.
final class BundleMedia {
  /// Creates the bundle context from its materialized [media] (images and
  /// clips) and [audio] entries, keyed by bundle-relative value.
  BundleMedia({
    Map<String, MediaSource> media = const {},
    Map<String, AudioSource> audio = const {},
  }) : media = Map.unmodifiable(media),
       audio = Map.unmodifiable(audio);

  /// The bundle context specs currently resolve against, or null outside any
  /// bundle. The loader that materialized a bundle owns this slot: set it
  /// when the bundle document opens, clear it when the document closes.
  static BundleMedia? current;

  /// Runs [build] with [bundle] as the resolution scope and returns its
  /// result; the previous scope is restored on exit. Passing null builds
  /// without a bundle — bundle sources then fail loudly.
  static T resolve<T>(BundleMedia? bundle, T Function() build) {
    final previous = current;
    current = bundle;
    try {
      return build();
    } finally {
      current = previous;
    }
  }

  /// Resolves a bundle media [value] against [current].
  ///
  /// Throws a [FluvieSpecError] (located under [path]) when no bundle is in
  /// scope or the bundle has no such entry.
  static MediaSource resolveMedia(String value, {List<String> path = const []}) =>
      _require(value, path).mediaFor(value, path: path);

  /// Resolves a bundle audio [value] against [current].
  ///
  /// Throws a [FluvieSpecError] (located under [path]) when no bundle is in
  /// scope or the bundle has no such entry.
  static AudioSource resolveAudio(String value, {List<String> path = const []}) =>
      _require(value, path).audioFor(value, path: path);

  static BundleMedia _require(String value, List<String> path) {
    final bundle = current;
    if (bundle == null) {
      throw FluvieSpecError(
        'A bundle source ("$value") can only build inside its .fluvie bundle; '
        'the loader materializes the bundle and sets BundleMedia.current '
        'before the spec builds',
        path: path,
      );
    }
    return bundle;
  }

  /// The materialized image and clip sources, keyed by bundle-relative value.
  final Map<String, MediaSource> media;

  /// The materialized audio sources, keyed by bundle-relative value.
  final Map<String, AudioSource> audio;

  /// The materialized media source stored under [value].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) naming the known entries
  /// when the bundle holds no such value.
  MediaSource mediaFor(String value, {List<String> path = const []}) {
    final source = media[value];
    if (source != null) return source;
    throw FluvieSpecError(
      'The bundle has no media entry "$value"; it holds ${_names(media.keys)}',
      path: path,
    );
  }

  /// The materialized audio source stored under [value].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) naming the known entries
  /// when the bundle holds no such value.
  AudioSource audioFor(String value, {List<String> path = const []}) {
    final source = audio[value];
    if (source != null) return source;
    throw FluvieSpecError(
      'The bundle has no audio entry "$value"; it holds ${_names(audio.keys)}',
      path: path,
    );
  }

  static String _names(Iterable<String> names) {
    if (names.isEmpty) return 'no entries';
    final sorted = names.toList()..sort();
    return sorted.map((name) => '"$name"').join(', ');
  }
}
