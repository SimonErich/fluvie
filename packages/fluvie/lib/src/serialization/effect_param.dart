part of 'effect_spec.dart';

/// One numeric parameter of an effect: its name, its honest range, and the
/// value the effect already uses when nobody says otherwise.
///
/// The range is the effect's own, not a guess: grain is a `[0, 1]` strength
/// because that is what it clamps to, and a document naming 5 is refused
/// rather than silently clamped into something the author did not write.
@immutable
final class EffectParam {
  /// Declares a parameter running from [min] to [max], defaulting to
  /// [defaultValue].
  const EffectParam(this.name, {required this.min, required this.max, required this.defaultValue});

  /// The JSON key.
  final String name;

  /// The lowest value the effect accepts.
  final double min;

  /// The highest value the effect accepts.
  final double max;

  /// What the effect uses when the document does not say.
  final double defaultValue;
}
