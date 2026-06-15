import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';

/// The JSON form of a [Time]: a unit-tagged string.
///
/// Frames are `"30f"`, seconds `"2.5s"`, milliseconds `"500ms"`, and a relative
/// fraction `"0.3r"` — capped relatives append the cap, as in `"0.2r@0.8s"`.
///
/// Composite times built with `+`, `-`, or `*` have no JSON form: they throw a
/// [FluvieSpecError] (located at [path]). Author durations as a single unit.
String encodeTime(Time time, {List<String> path = const []}) => switch (time) {
  FrameTime(:final frames) => '${frames}f',
  SecondTime(:final seconds) => '${seconds}s',
  MsTime(:final milliseconds) => '${milliseconds}ms',
  RelativeTime(:final fraction, :final max) =>
    max == null ? '${fraction}r' : '${fraction}r@${encodeTime(max, path: path)}',
  _ => throw FluvieSpecError(
    'This Time has no JSON form: composite times from +, -, or * are not '
    'serializable ($time). Author the duration as a single unit.',
    path: path,
  ),
};

/// Reads a [Time] from a unit-tagged string in [raw] (see [encodeTime]).
///
/// Throws a [FluvieSpecError] (located at [path]) when [raw] is not a string or
/// carries no recognized unit.
Time decodeTime(Object? raw, {List<String> path = const []}) {
  if (raw is! String) {
    throw FluvieSpecError('Expected a time string like "2s", "30f", or "0.3r"', path: path);
  }
  final text = raw.trim();
  final rIndex = text.indexOf('r');
  if (rIndex > 0) {
    final fraction = double.tryParse(text.substring(0, rIndex));
    if (fraction == null) {
      throw FluvieSpecError('Invalid relative time "$raw"', path: path);
    }
    final rest = text.substring(rIndex + 1);
    if (rest.isEmpty) return Time.relative(fraction);
    if (rest.startsWith('@')) {
      return Time.relative(fraction, max: decodeTime(rest.substring(1), path: path));
    }
    throw FluvieSpecError('Invalid relative time "$raw"; cap form is "0.2r@0.8s"', path: path);
  }
  if (text.endsWith('ms')) {
    final ms = int.tryParse(text.substring(0, text.length - 2));
    if (ms == null) throw FluvieSpecError('Invalid millisecond time "$raw"', path: path);
    return Time.ms(ms);
  }
  if (text.endsWith('f')) {
    final frames = int.tryParse(text.substring(0, text.length - 1));
    if (frames == null) throw FluvieSpecError('Invalid frame time "$raw"', path: path);
    return Time.frames(frames);
  }
  if (text.endsWith('s')) {
    final seconds = double.tryParse(text.substring(0, text.length - 1));
    if (seconds == null) throw FluvieSpecError('Invalid second time "$raw"', path: path);
    return Time.seconds(seconds);
  }
  throw FluvieSpecError(
    'Unrecognized time "$raw"; use "2s", "500ms", "30f", or "0.3r"',
    path: path,
  );
}
