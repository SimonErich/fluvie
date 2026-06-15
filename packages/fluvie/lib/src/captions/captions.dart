import 'package:fluvie/src/captions/caption_position.dart';
import 'package:fluvie/src/captions/caption_style.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/captions/caption_word.dart';
import 'package:meta/meta.dart';

/// A first-class caption track: imported from SRT/VTT or built inline,
/// styled and safe-area positioned.
///
/// The track carries its origin as a [captionSource] the collect pass gathers
/// and the resolver reads + parses once before frame 0 (so an SRT/VTT file is
/// never read mid-frame). [style] picks the look ([CaptionStyle.tikTok] /
/// [CaptionStyle.subtitle] / [CaptionStyle.karaoke], or a custom one); `null`
/// falls back to the theme's `captions.defaultStyle`. [position] places the
/// block ([CaptionPosition.bottomThird] by default when `null`). The
/// caption layer mounts above the composition and shows the active cue.
@immutable
final class Captions {
  // Reason: const-ctor artifacts. The caption feature tests pin the fromSrt and
  // fromVtt fields.
  // coverage:ignore-start
  /// Captions imported from the SubRip file at [path], optionally [style]d and
  /// [position]ed.
  const Captions.fromSrt(String path, {this.style, this.position})
    : source = path,
      words = const [],
      _format = _CaptionFormat.srt;

  /// Captions imported from the WebVTT file at [path], optionally [style]d and
  /// [position]ed.
  const Captions.fromVtt(String path, {this.style, this.position})
    : source = path,
      words = const [],
      _format = _CaptionFormat.vtt;
  // coverage:ignore-end

  /// Captions built inline from timed [words], optionally [style]d and
  /// [position]ed.
  ///
  /// The list is copied and unmodifiable — captions stay value data even when
  /// the caller mutates its own list afterwards.
  Captions.words(List<CaptionWord> words, {this.style, this.position})
    : source = null,
      words = List.unmodifiable(words),
      _format = _CaptionFormat.inline;

  /// The caption file this track imports, or `null` for an inline track.
  final String? source;

  /// The inline words of this track, in display order; empty for a file
  /// import. Unmodifiable.
  final List<CaptionWord> words;

  /// How the track is drawn, or `null` to use the theme's default caption
  /// style.
  final CaptionStyle? style;

  /// Where the track sits on the canvas, or `null` for the bottom-third
  /// default.
  final CaptionPosition? position;

  final _CaptionFormat _format;

  /// The origin the collect pass gathers and the resolver reads + parses before
  /// frame 0.
  CaptionSource get captionSource => switch (_format) {
    _CaptionFormat.srt => CaptionSource.srt(source!),
    _CaptionFormat.vtt => CaptionSource.vtt(source!),
    _CaptionFormat.inline => CaptionSource.inline(words),
  };

  @override
  String toString() =>
      source == null ? 'Captions.words(${words.length} words)' : 'Captions($source)';
}

/// Which caption origin a [Captions] track carries, so `captionSource` can build
/// the right [CaptionSource] variant without inverting the const constructors.
enum _CaptionFormat { srt, vtt, inline }
