import 'package:meta/meta.dart';

/// The payload an effect chip drags: the effect's document JSON, ready to
/// land as an add wherever it is dropped — the canvas and the timeline both
/// turn it into the same command, so the two gestures cannot drift.
@immutable
final class EffectDragData {
  /// Wraps the dragged [effect] JSON (`kind` included).
  const EffectDragData(this.effect);

  /// The effect's document form.
  final Map<String, Object?> effect;
}
