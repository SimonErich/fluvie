part of 'spec_validation.dart';

/// Builds the diagnostic for an unknown [key] on [subject], naming the [allowed]
/// keys and adding a hint when [key] is a near-miss or a misplaced style field
/// (the latter only when [elementType] is a `Text`/`Counter`).
String _message(String key, String subject, Set<String> allowed, String? elementType) {
  final buffer = StringBuffer('Unknown property "$key" on $subject.');
  final hint = _styleNestHint(key, elementType) ?? _didYouMean(key, allowed);
  if (hint != null) buffer.write(' $hint');
  final sorted = allowed.toList()..sort();
  buffer.write(' allowed: ${sorted.join(', ')}.');
  return buffer.toString();
}

String? _styleNestHint(String key, String? elementType) {
  if ((elementType == 'Text' || elementType == 'Counter') && _styleFields.contains(key)) {
    return 'Did you mean to nest it inside "style"?';
  }
  return null;
}

String? _didYouMean(String key, Set<String> allowed) {
  String? best;
  var bestDistance = 1 << 30;
  for (final candidate in allowed) {
    final distance = _levenshtein(key.toLowerCase(), candidate.toLowerCase());
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best != null && bestDistance <= 2 ? 'Did you mean "$best"?' : null;
}

/// The edit distance between [a] and [b] (two short property names), used only
/// for the near-miss hint.
int _levenshtein(String a, String b) {
  final n = b.length;
  if (a.isEmpty) return n;
  if (n == 0) return a.length;
  var previous = List<int>.generate(n + 1, (i) => i);
  var current = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + cost;
      var min = deletion < insertion ? deletion : insertion;
      if (substitution < min) min = substitution;
      current[j] = min;
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[n];
}
