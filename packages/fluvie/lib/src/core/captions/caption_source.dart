import 'dart:convert';

import 'package:fluvie/src/core/captions/caption_word.dart';
import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:meta/meta.dart';

/// One declared caption origin, identified before it is read.
///
/// A `CaptionSource` is the key the caption pre-pass works over: `Captions`
/// exposes one, the collect pass gathers it, and the `MediaResolver` reads the
/// file (via the byte loader) and parses it to `CaptionCue`s once before frame 0
/// — captions never read or parse mid-frame, the determinism rule. It
/// mirrors `AudioSource`/`SnapshotSource`: a sealed value with a stable,
/// path-safe [cacheKey] (the FNV-1a-64 hash of a canonical string that
/// distinguishes the format and path), so an identical declaration shares one
/// cache entry. It carries only Dart-core types, so it lives in the captions
/// layer without inverting the layering.
///
/// `Captions` and `MediaResolver` are named in prose, not as doc links, because
/// the resolver lives in a sibling layer and a link would invert the layering.
@immutable
sealed class CaptionSource {
  const CaptionSource();

  /// A SubRip file at [path] (parsed by the SRT parser before frame 0).
  const factory CaptionSource.srt(String path) = SrtCaptionSource;

  /// A WebVTT file at [path] (parsed by the VTT parser before frame 0).
  const factory CaptionSource.vtt(String path) = VttCaptionSource;

  /// Inline [words] that need no IO (the cues come straight from the list).
  const factory CaptionSource.inline(List<CaptionWord> words) = InlineCaptionSource;

  /// The canonical string that fully identifies this source — hashed into
  /// [cacheKey]. Distinct for every field that changes the parsed cues.
  String get _canonical;

  /// The path-safe content-hash key for the caption cache.
  String get cacheKey => fnv1a64Hex(utf8.encode(_canonical));
}

/// A [CaptionSource] backed by a SubRip file.
final class SrtCaptionSource extends CaptionSource {
  /// Creates an SRT source at [path].
  const SrtCaptionSource(this.path);

  /// The SubRip file path to read and parse.
  final String path;

  @override
  String get _canonical => 'srt|$path';

  @override
  bool operator ==(Object other) => other is SrtCaptionSource && other.path == path;

  @override
  int get hashCode => Object.hash(SrtCaptionSource, path);

  @override
  String toString() => 'CaptionSource.srt($path)';
}

/// A [CaptionSource] backed by a WebVTT file.
final class VttCaptionSource extends CaptionSource {
  /// Creates a VTT source at [path].
  const VttCaptionSource(this.path);

  /// The WebVTT file path to read and parse.
  final String path;

  @override
  String get _canonical => 'vtt|$path';

  @override
  bool operator ==(Object other) => other is VttCaptionSource && other.path == path;

  @override
  int get hashCode => Object.hash(VttCaptionSource, path);

  @override
  String toString() => 'CaptionSource.vtt($path)';
}

/// A [CaptionSource] backed by inline words, needing no IO.
final class InlineCaptionSource extends CaptionSource {
  /// Creates an inline source over [words].
  const InlineCaptionSource(this.words);

  /// The inline words, used verbatim with no file read.
  final List<CaptionWord> words;

  @override
  String get _canonical => 'inline|${words.map((w) => '${w.text}@${w.at}').join('|')}';

  @override
  bool operator ==(Object other) => other is InlineCaptionSource && _sameWords(other.words, words);

  @override
  int get hashCode => Object.hash(InlineCaptionSource, Object.hashAll(words));

  static bool _sameWords(List<CaptionWord> a, List<CaptionWord> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'CaptionSource.inline(${words.length} words)';
}
