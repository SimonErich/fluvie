/// Shared discipline for the typed audio filter graph.
///
/// The audio nodes (`AudioTrackNode`, `AmixNode`) build a `-filter_complex`
/// graph as typed values, never a hand-built shell string. This file holds the
/// two primitives every node reuses: a sandbox-relative name validator (the
/// same security boundary as the video arg builder's `_validateName`) and a
/// deterministic number formatter so a value like `1.0` always serializes the
/// same way across runs.
///
/// `AudioTrackNode` and `AmixNode` are named in prose, not as doc links,
/// because importing them here would be circular.
library;

/// Rejects anything that is not a bare sandbox-relative file name (the audio
/// mirror of the video arg builder's name gate): empty names, names with `/`
/// or `\` separators (covers `../` traversal and absolute paths), and names
/// starting with `-` (flag injection). Returns [name] unchanged when safe.
String validateAudioName(String name, [String parameter = 'name']) {
  if (name.isEmpty) {
    throw ArgumentError.value(name, parameter, 'must not be empty');
  }
  if (name.startsWith('-')) {
    throw ArgumentError.value(name, parameter, 'must not start with "-" (flag injection)');
  }
  if (name.contains('/') || name.contains(r'\')) {
    throw ArgumentError.value(
      name,
      parameter,
      'must be a bare sandbox-relative file name without path separators',
    );
  }
  return name;
}

/// Formats [value] deterministically for a filter argument: a whole number
/// drops its `.0` (so `2.0` becomes `2`), every other value uses its default
/// `double` form. Only ever called on values this library computes (delays,
/// seconds, gains), never on external strings.
String formatFilterNumber(num value) {
  if (value is int) return '$value';
  if (value == value.roundToDouble() && value.isFinite) return '${value.toInt()}';
  return '$value';
}
