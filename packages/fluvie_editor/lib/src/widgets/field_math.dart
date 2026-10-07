// obers_ui upstream candidate: the pocket-calculator grammar every numeric
// inspector field accepts.

/// Evaluates [input] the way an inspector field expects: a plain number or
/// a `+ - * /` expression (with parentheses) evaluates absolutely, while a
/// leading `+`, `*`, or `/` applies the rest to [current] (`+10` nudges,
/// `*2` doubles). A leading `-` sets a negative value — negatives are legal
/// positions, so it never means "subtract".
///
/// Returns null for anything that does not parse (or divides by zero); the
/// field keeps its old value.
double? evalFieldMath(String input, {required double current}) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final relative = switch (text[0]) {
    '+' => (double rest) => current + rest,
    '*' => (double rest) => current * rest,
    '/' => (double rest) => rest == 0 ? null : current / rest,
    _ => null,
  };
  final body = relative == null ? text : text.substring(1);
  final value = _Parser(body).parse();
  if (value == null || !value.isFinite) return null;
  final result = relative == null ? value : relative(value);
  return result != null && result.isFinite ? result : null;
}

/// A tiny recursive-descent parser: expr := term (('+'|'-') term)*;
/// term := factor (('*'|'/') factor)*; factor := number | '(' expr ')'.
final class _Parser {
  _Parser(this._text);

  final String _text;
  int _index = 0;
  bool _failed = false;

  double? parse() {
    final value = _expr();
    _skipSpace();
    if (_failed || _index != _text.length) return null;
    return value;
  }

  double _expr() {
    var value = _term();
    while (true) {
      _skipSpace();
      if (_peek == '+') {
        _index++;
        value += _term();
      } else if (_peek == '-') {
        _index++;
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _factor();
    while (true) {
      _skipSpace();
      if (_peek == '*') {
        _index++;
        value *= _factor();
      } else if (_peek == '/') {
        _index++;
        final divisor = _factor();
        if (divisor == 0) _failed = true;
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _factor() {
    _skipSpace();
    if (_peek == '(') {
      _index++;
      final value = _expr();
      _skipSpace();
      if (_peek == ')') {
        _index++;
        return value;
      }
      _failed = true;
      return double.nan;
    }
    final negative = _peek == '-';
    if (negative) _index++;
    final start = _index;
    while (_index < _text.length && (RegExp('[0-9.]').hasMatch(_text[_index]))) {
      _index++;
    }
    final number = double.tryParse(_text.substring(start, _index));
    if (number == null) {
      _failed = true;
      return double.nan;
    }
    return negative ? -number : number;
  }

  String? get _peek => _index < _text.length ? _text[_index] : null;

  void _skipSpace() {
    while (_index < _text.length && _text[_index] == ' ') {
      _index++;
    }
  }
}
