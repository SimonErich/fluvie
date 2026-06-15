import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

/// The JSON form of any [Enum] value: its `name`.
///
/// Names are stable API in the spec, exactly as they are in render-config JSON,
/// so the spelling round-trips byte for byte.
String encodeEnum(Enum value) => value.name;

/// Reads an enum value of type [T] from its `name` in [raw].
///
/// [values] is the enum's `.values` list and [label] names the enum in error
/// messages. Throws a [FluvieSpecError] (located at [path]) when [raw] is not a
/// string or names no member of [values].
T decodeEnum<T extends Enum>(
  List<T> values,
  Object? raw,
  String label, {
  List<String> path = const [],
}) {
  if (raw is! String) {
    throw FluvieSpecError('Expected a $label name (a string)', path: path);
  }
  for (final value in values) {
    if (value.name == raw) return value;
  }
  final allowed = values.map((value) => value.name).join(', ');
  throw FluvieSpecError('Unknown $label "$raw"; expected one of: $allowed', path: path);
}
