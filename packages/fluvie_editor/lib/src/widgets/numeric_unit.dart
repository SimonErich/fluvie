import 'package:meta/meta.dart';

/// How a numeric field shows and reads its value.
///
/// The value itself is always a plain `double` in the field's own domain —
/// frames, pixels, degrees. A unit only changes how that number is written and
/// parsed, so nothing downstream has to know which unit a field is wearing.
enum NumericUnit {
  /// A bare number.
  plain,

  /// A whole number of frames, written `120f`.
  frames,

  /// Seconds, written `4s` — the value is still in frames, converted at the
  /// field's own rate.
  seconds,

  /// `HH:MM:SS:FF` at the field's rate — the value is still in frames.
  timecode,

  /// A percentage, written `50%` — the value is a fraction, so `0.5` shows as
  /// `50%`.
  percent,

  /// Degrees, written `45°`.
  degrees,
}

/// Formats and parses a value for one [NumericUnit] at one frame rate.
///
/// A value type rather than a pile of functions so a field carries its unit and
/// its rate together: a timecode is meaningless without knowing what rate its
/// frames are counted at, and the two drifting apart is exactly how a field
/// starts lying.
@immutable
final class NumericFormat {
  /// Formats [unit] at [fps] with [decimals] fraction digits where the unit
  /// admits them.
  const NumericFormat({this.unit = NumericUnit.plain, this.fps = 30, this.decimals = 1})
    : assert(fps > 0, 'fps must be positive');

  /// The unit this field wears.
  final NumericUnit unit;

  /// The rate frames are counted at, for the frame-based units.
  final int fps;

  /// Fraction digits for the units that admit them.
  final int decimals;

  /// [value] written the way this field shows it.
  String format(double value) => switch (unit) {
    NumericUnit.plain => _number(value),
    NumericUnit.frames => '${value.round()}f',
    NumericUnit.seconds => '${_number(value / fps)}s',
    NumericUnit.timecode => formatTimecode(value.round(), fps),
    NumericUnit.percent => '${_number(value * 100)}%',
    NumericUnit.degrees => '${_number(value)}°',
  };

  /// [text] read back into the field's own domain, or null when it is not a
  /// value in this unit at all.
  ///
  /// The unit suffix is optional on input: an author who types `120` into a
  /// frames field means 120 frames, and making them type the `f` would be
  /// pedantry. A timecode field is the exception — it needs the colons to know
  /// which part is which.
  double? parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (unit == NumericUnit.timecode) return parseTimecode(trimmed, fps)?.toDouble();
    final bare = trimmed.replaceAll(RegExp(r'[fs%°]$'), '').trim();
    final number = double.tryParse(bare);
    if (number == null) return null;
    return switch (unit) {
      NumericUnit.plain || NumericUnit.frames || NumericUnit.degrees => number,
      NumericUnit.seconds => number * fps,
      NumericUnit.percent => number / 100,
      NumericUnit.timecode => null, // handled above
    };
  }

  String _number(double value) {
    if (value == value.roundToDouble()) return '${value.round()}';
    return value.toStringAsFixed(decimals);
  }
}

/// [frames] as `HH:MM:SS:FF` at [fps].
///
/// Non-drop-frame only, and deliberately so: drop-frame timecode renumbers
/// frames to track 29.97, which would make the label disagree with the frame
/// index every other surface in the editor counts in. A rate that needs it is
/// better refused than silently mislabelled.
String formatTimecode(int frames, int fps) {
  final safe = frames < 0 ? 0 : frames;
  final totalSeconds = safe ~/ fps;
  final frame = safe % fps;
  final seconds = totalSeconds % 60;
  final minutes = (totalSeconds ~/ 60) % 60;
  final hours = totalSeconds ~/ 3600;
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(hours)}:${pad(minutes)}:${pad(seconds)}:${pad(frame)}';
}

/// `HH:MM:SS:FF`, `MM:SS:FF` or `SS:FF` at [fps] as a frame count, or null
/// when [text] is not a timecode.
///
/// Shorter forms are accepted because typing four fields to move two seconds
/// is a tax; the parts are read from the right, so the last one is always
/// frames. A frame part at or above [fps] is refused rather than silently
/// carried, since it names a frame that does not exist at this rate.
int? parseTimecode(String text, int fps) {
  final parts = text.split(':');
  if (parts.length < 2 || parts.length > 4) return null;
  final numbers = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part.trim());
    if (value == null || value < 0) return null;
    numbers.add(value);
  }
  final frames = numbers.removeLast();
  if (frames >= fps) return null;
  var seconds = 0;
  if (numbers.isNotEmpty) seconds += numbers.removeLast();
  if (numbers.isNotEmpty) seconds += numbers.removeLast() * 60;
  if (numbers.isNotEmpty) seconds += numbers.removeLast() * 3600;
  return seconds * fps + frames;
}
