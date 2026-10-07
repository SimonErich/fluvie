import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/stagger/multi_child_rebuilder.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';

/// How a [SplitText] headline is divided before stagger distribution.
enum TextSplit {
  /// Extended grapheme clusters: an emoji or combining sequence stays whole.
  character,

  /// Words including their following horizontal whitespace.
  word,

  /// Explicit lines, including a trailing empty line.
  line,
}

/// A headline whose parts receive the existing `.animate(stagger: ...)`
/// distribution. It shares the same animation clock and preset pipeline as
/// every other multi-child target; splitting introduces no separate timing.
final class SplitText extends StatelessWidget implements StaggerChildren, CollectibleChildren {
  /// Splits [text] with [by], preserving explicit line breaks and whitespace.
  SplitText(
    this.text, {
    this.by = TextSplit.word,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    super.key,
  }) : assert(maxLines == null || maxLines > 0, 'maxLines must be positive'),
       parts = splitTextParts(text, by);

  /// The complete, accessible text.
  final String text;

  /// The unit each staggered child represents.
  final TextSplit by;

  /// The style shared by every part.
  final TextStyle? style;

  /// Alignment of each wrapped line.
  final TextAlign textAlign;

  /// Optional maximum number of explicit lines.
  final int? maxLines;

  /// The exact split units, before animation wrapping.
  final List<String> parts;

  @override
  // The default TextWidthBasis.parent preserves trailing space advances.
  // longestLine would trim them and visually concatenate adjacent words.
  List<Widget> get staggerChildren => [
    for (final part in parts) Text(part, style: style, textAlign: textAlign),
  ];
  @override
  Iterable<Widget> get collectibleChildren => staggerChildren;
  @override
  Widget withStaggerChildren(List<Widget> children) => _layout(children);
  @override
  Widget build(BuildContext context) => _layout(staggerChildren);

  Widget _layout(List<Widget> children) {
    final lines = <List<Widget>>[[]];
    for (var i = 0; i < children.length; i++) {
      if (by == TextSplit.line) {
        if (i > 0) lines.add([]);
        lines.last.add(children[i]);
      } else if (parts[i].contains('\n') || parts[i].contains('\r')) {
        for (var n = 0; n < RegExp(r'\r\n|\r|\n').allMatches(parts[i]).length; n++) {
          lines.add([]);
        }
      } else {
        lines.last.add(children[i]);
      }
    }
    final alignment = switch (textAlign) {
      TextAlign.center => WrapAlignment.center,
      TextAlign.right || TextAlign.end => WrapAlignment.end,
      _ => WrapAlignment.start,
    };
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: switch (textAlign) {
          TextAlign.center => CrossAxisAlignment.center,
          TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        },
        children: [
          for (final line in maxLines == null ? lines : lines.take(maxLines!))
            if (line.isEmpty)
              Text('', style: style)
            else
              Wrap(alignment: alignment, children: line),
        ],
      ),
    );
  }
}

/// Pure split tables shared by authoring, collection and rendering.
List<String> splitTextParts(String text, TextSplit by) {
  if (text.isEmpty) return const [];
  return switch (by) {
    TextSplit.character => text.characters.toList(),
    TextSplit.word => [
      for (final match in RegExp(r'[^\s]+[^\S\r\n]*|\r\n|[\r\n]|[^\S\r\n]+').allMatches(text))
        match.group(0)!,
    ],
    TextSplit.line => text.split(RegExp(r'\r\n|\r|\n')),
  };
}
