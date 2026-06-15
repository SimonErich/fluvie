import 'package:flutter/widgets.dart';
import 'package:fluvie/src/captions/caption_position.dart';
import 'package:fluvie/src/captions/caption_style.dart';
import 'package:fluvie/src/captions/runtime/caption_word_pop.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Renders one active [CaptionCue] styled and positioned — the body of the
/// caption layer, split out so the layer stays small.
///
/// The cue's words lay out in a `Wrap` over the style's background, aligned by
/// [position] with its safe-area inset. When [CaptionStyle.wordPop] is set each
/// word scales in via [wordPopScale] (a `Transform.scale`, the shared widget,
/// driven by the shared Animation progress math — no bespoke caption
/// animation). When [CaptionStyle.karaoke] is set the active word (by its word
/// timing) takes the highlight color while the rest stay dimmed.
final class CaptionCueView extends StatelessWidget {
  /// Creates the view of [cue] at [frame] within [scope], drawn with [style] at
  /// [position].
  const CaptionCueView({
    required this.cue,
    required this.frame,
    required this.scope,
    required this.style,
    required this.position,
    super.key,
  });

  /// The cue to render.
  final CaptionCue cue;

  /// The current frame, for word-pop and karaoke timing.
  final int frame;

  /// The time scope the cue and word times resolve against.
  final TimeScopeData scope;

  /// How the cue is drawn.
  final CaptionStyle style;

  /// Where the cue sits on the canvas.
  final CaptionPosition position;

  /// Whether the cue must render word by word (word-pop or karaoke); a plain
  /// subtitle renders as one text block for clean wrapping.
  bool get _perWord => style.wordPop || style.karaoke;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(position.safeArea),
    child: Align(
      alignment: position.alignment,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _perWord ? _wordRow() : _plainText(),
        ),
      ),
    ),
  );

  /// The whole cue text as one centered block (the subtitle path).
  Widget _plainText() => Text(cue.text, style: style.textStyle, textAlign: TextAlign.center);

  /// The cue laid out word by word, for word-pop and karaoke.
  Widget _wordRow() {
    final words = _words();
    final starts = wordStartFrames(cue, scope);
    final active = activeWordIndex(cue, frame: frame, scope: scope);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var i = 0; i < words.length; i++)
          _word(words[i], startFrame: i < starts.length ? starts[i] : null, isActive: i == active),
      ],
    );
  }

  /// One styled (and optionally popped) word.
  Widget _word(String text, {required int? startFrame, required bool isActive}) {
    final textStyle = style.karaoke && isActive
        ? style.textStyle.copyWith(color: style.highlight)
        : style.textStyle;
    final label = Text(text, style: textStyle, textAlign: TextAlign.center);
    if (!style.wordPop || startFrame == null) return label;
    final scale = wordPopScale(frame: frame, wordStartFrame: startFrame, fps: scope.fps);
    return Transform.scale(scale: scale, child: label);
  }

  /// The cue's display words: its word-level timing when present, otherwise the
  /// whitespace-split text.
  List<String> _words() => cue.words.isNotEmpty
      ? [for (final word in cue.words) word.text]
      : cue.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
}
