import 'package:fluvie/fluvie.dart' show MsTime, SecondTime, Time, decodeTime;

/// A clip's trim read in source **seconds**, plus whether each bound was
/// actually written.
///
/// Seconds rather than source frames, because source frames only mean
/// something at the source's own frame rate and the editor cannot read it. A
/// verb that has to move a trim can do all of its arithmetic here and stay
/// exact whatever the footage turns out to be.
typedef ClipTrimSeconds = ({double from, double to, bool fromOpen, bool toOpen});

/// The message a verb gives back when a trim is written in a unit it cannot
/// convert on its own.
const String clipTrimUnitNote =
    'Rewrite this clip trim in seconds first. Source frames and relative '
    'times only mean something at the source rate, which the editor cannot '
    'read, and shifting them by a guessed rate would move the wrong footage.';

/// [element]'s trim in source seconds, or null when a bound is written in a
/// unit the editor cannot convert.
///
/// A clip with no trim reads as open at zero: the whole source, starting at
/// its beginning.
ClipTrimSeconds? readClipTrimSeconds(Map<String, Object?> element) {
  final raw = element['trim'];
  final trim = raw is Map<String, Object?> ? raw : null;
  final from = _bound(trim?['from']);
  final to = _bound(trim?['to']);
  if (from == null || to == null) return null;
  return (from: from.value, to: to.value, fromOpen: from.open, toOpen: to.open);
}

/// The clip's playback rate, defaulting to one.
double clipSpeedOf(Map<String, Object?> element) => switch (element['speed']) {
  final num rate => rate.toDouble(),
  _ => 1.0,
};

/// A trim range in the JSON form the spec reads.
Map<String, Object?> trimSecondsJson(double from, double to) => {
  'from': '${from}s',
  'to': '${to}s',
};

/// One bound in source seconds, and whether it was there at all.
({double value, bool open})? _bound(Object? raw) {
  if (raw == null) return (value: 0, open: true);
  final Time time;
  try {
    time = decodeTime(raw);
  } on Object {
    return null;
  }
  return switch (time) {
    SecondTime(:final seconds) => (value: seconds, open: false),
    MsTime(:final milliseconds) => (value: milliseconds / 1000, open: false),
    _ => null,
  };
}
