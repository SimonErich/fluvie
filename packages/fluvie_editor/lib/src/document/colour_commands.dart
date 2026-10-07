part of 'editor_command.dart';

/// Replaces just the colour effects across a selection in one undo step,
/// preserving all motion/film effects and their relative order.
final class ApplyColourCommand extends EditorCommand {
  /// Applies [effects] to every element in [ids].
  const ApplyColourCommand({required this.ids, required this.effects, this.name = 'Colour'});

  /// The selected element ids receiving this colour treatment.
  final List<String> ids;

  /// The colour effects to replace the old treatment with.
  final List<Map<String, Object?>> effects;

  /// The treatment name shown in undo history.
  final String name;

  @override
  EditorDocument apply(EditorDocument document) {
    var next = document;
    for (final id in ids) {
      final existing = next.elementJson(id)?['effects'];
      if (existing is List) {
        for (var i = existing.length - 1; i >= 0; i--) {
          if (const {'grade', 'curves', 'lut'}.contains((existing[i] as Map)['kind'])) {
            next = next.removeEffect(id, i);
          }
        }
      }
      for (final effect in effects) {
        next = next.addEffect(id, effect);
      }
    }
    return next;
  }

  @override
  String get label => 'Apply $name to ${ids.length} elements';
  @override
  Set<String> get affectedIds => {...ids};
}

/// Edits coupled grade parameters as one intention, for the balance wheel.
final class SetEffectParamsCommand extends EditorCommand {
  /// Patches coupled parameters on one effect as one undo step.
  const SetEffectParamsCommand({required this.id, required this.index, required this.params});

  /// The element whose effect is edited.
  final String id;

  /// The effect index in the element’s ordered stack.
  final int index;

  /// The parameter patch to apply atomically.
  final Map<String, Object?> params;
  @override
  EditorDocument apply(EditorDocument document) => document.updateEffect(id, index, params);
  @override
  String get label => 'Adjust colour balance';
  @override
  Set<String> get affectedIds => {id};
}
