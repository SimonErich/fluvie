part of 'element_builder.dart';

/// A `Text` from its spec props: plain `text`, or styled `spans` — exactly one
/// of the two. Lists and block structure stay `Markdown`'s surface; `spans`
/// carry inline styling and links only.
Widget _text(Map<String, Object?> props) {
  final text = props['text'];
  final spans = props['spans'];
  if ((text == null) == (spans == null)) {
    throw FluvieSpecError('A Text takes exactly one of "text" or "spans"', path: const ['text']);
  }
  final style = props['style'] == null
      ? null
      : decodeTextStyle(props['style'], path: const ['style']);
  final textAlign = props['textAlign'] == null
      ? null
      : decodeEnum(TextAlign.values, props['textAlign'], 'textAlign', path: const ['textAlign']);
  final maxLines = _maybeInt(props['maxLines'], 'maxLines');
  final framed =
      props['decoration'] != null || props['padding'] != null || props['maxWidth'] != null;
  final label = spans == null
      ? Text(
          _string(text, 'text'),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          textWidthBasis: framed ? TextWidthBasis.longestLine : TextWidthBasis.parent,
        )
      : Text.rich(
          TextSpan(children: _spanList(spans)),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          textWidthBasis: framed ? TextWidthBasis.longestLine : TextWidthBasis.parent,
        );
  if (!framed) return label;
  final padding = props['padding'];
  if (padding != null && padding is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a padding object', path: const ['padding']);
  }
  double inset(String key) {
    final value = padding is Map ? padding[key] : null;
    if (value == null) return 0;
    if (value is! num || !value.isFinite || value < 0) {
      throw FluvieSpecError('Expected a finite nonnegative inset', path: ['padding', key]);
    }
    return value.toDouble();
  }

  final maxWidth = props['maxWidth'];
  if (maxWidth != null && (maxWidth is! num || !maxWidth.isFinite || maxWidth <= 0)) {
    throw FluvieSpecError('Expected a finite positive width', path: const ['maxWidth']);
  }
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth is num ? maxWidth.toDouble() : double.infinity),
    child: Align(
      widthFactor: 1,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: props['decoration'] == null
            ? const BoxDecoration()
            : decodeBoxDecoration(props['decoration'], path: const ['decoration']),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inset('horizontal'),
            vertical: inset('vertical'),
          ),
          child: label,
        ),
      ),
    ),
  );
}

List<TextSpan> _spanList(Object? raw) {
  if (raw is! List || raw.isEmpty) {
    throw FluvieSpecError('Expected a non-empty "spans" list', path: const ['spans']);
  }
  return [for (var i = 0; i < raw.length; i++) _span(raw[i], i)];
}

/// One styled span. A `link` span merges an underline into its style (the
/// authored style wins on conflicts) and carries the uri on the span's
/// semantics label — never a gesture recognizer, so a rendered link is
/// visible and announced but not interactive (capture-safe).
TextSpan _span(Object? raw, int index) {
  final path = ['spans', '$index'];
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a span object', path: path);
  }
  final text = raw['text'];
  if (text is! String) {
    throw FluvieSpecError('A span needs a string "text"', path: [...path, 'text']);
  }
  final link = raw['link'];
  if (link != null && link is! String) {
    throw FluvieSpecError('Expected a string "link"', path: [...path, 'link']);
  }
  final style = raw['style'] == null
      ? null
      : decodeTextStyle(raw['style'], path: [...path, 'style']);
  if (link is! String) return TextSpan(text: text, style: style);
  return TextSpan(
    text: text,
    style: const TextStyle(decoration: TextDecoration.underline).merge(style),
    semanticsLabel: '$text, link to $link',
  );
}
