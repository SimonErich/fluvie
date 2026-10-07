part of 'element_builder.dart';

// The scalar prop readers every element case shares, plus the Counter case
// (whose props are all scalars). Each reader throws a located FluvieSpecError
// so a wrong-typed prop names its own field.

String _string(Object? raw, String field) {
  if (raw is String) return raw;
  throw FluvieSpecError('Expected a string "$field"', path: [field]);
}

Size? _size(Object? raw) {
  if (raw == null) return null;
  if (raw is Map<String, Object?>) {
    final width = raw['width'];
    final height = raw['height'];
    if (width is num && height is num) return Size(width.toDouble(), height.toDouble());
  }
  throw FluvieSpecError('Expected a size {width, height}', path: const ['size']);
}

num _num(Object? raw, String field) {
  if (raw is num) return raw;
  throw FluvieSpecError('Expected a number "$field"', path: [field]);
}

num _numOr(Object? raw, num fallback) => raw is num ? raw : fallback;

int? _maybeInt(Object? raw, String field) {
  if (raw == null) return null;
  if (raw is int) return raw;
  throw FluvieSpecError('Expected an integer "$field"', path: [field]);
}

bool _boolOr(Object? raw, bool fallback, String field) {
  if (raw == null) return fallback;
  if (raw is bool) return raw;
  throw FluvieSpecError('Expected a boolean "$field"', path: [field]);
}

/// A `Counter` from its spec props: `variant` picks the plain, currency, or
/// percent constructor, mirroring the widget defaults.
Counter _counter(Map<String, Object?> props) {
  final to = _num(props['to'], 'to');
  final from = _numOr(props['from'], 0);
  final reveal = props['reveal'] == null
      ? const Time.seconds(1)
      : decodeTime(props['reveal'], path: const ['reveal']);
  final ease = props['ease'] == null
      ? Ease.linear
      : decodeCurve(props['ease'], path: const ['ease']);
  final style = props['style'] == null
      ? null
      : decodeTextStyle(props['style'], path: const ['style']);
  final symbol = props['symbol'];
  return switch (props['variant']) {
    null => Counter(to: to, from: from, reveal: reveal, ease: ease, style: style),
    'currency' => Counter.currency(
      to: to,
      symbol: symbol is String ? symbol : r'$',
      from: from,
      reveal: reveal,
      ease: ease,
      style: style,
    ),
    'percent' => Counter.percent(to: to, from: from, reveal: reveal, ease: ease, style: style),
    final variant => throw FluvieSpecError(
      'Unknown counter variant "$variant"; expected "currency" or "percent"',
      path: const ['variant'],
    ),
  };
}
