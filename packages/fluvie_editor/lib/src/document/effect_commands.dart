part of 'editor_command.dart';

/// Appends one effect to an element's stack — the Effects tab's add, and
/// where a browser drop on the canvas or a timeline bar lands.
final class AddEffectCommand extends EditorCommand {
  /// Appends [effect] (its JSON form, `kind` included) to element [id].
  const AddEffectCommand({required this.id, required this.effect});

  /// The element gaining the effect.
  final String id;

  /// The effect's JSON, exactly as the document will carry it.
  final Map<String, Object?> effect;

  @override
  EditorDocument apply(EditorDocument document) => document.addEffect(id, effect);

  @override
  String get label => 'Add ${effect['kind']} to $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Appends a whole copied stack onto every named element, as one undo step.
///
/// Deep-copied per element on apply so the pasted effects share no structure
/// with the clipboard's or with each other — the same discipline the
/// elements paste applies, minus the id re-mint, because effects carry none.
final class PasteEffectsCommand extends EditorCommand {
  /// Appends [effects] (their JSON forms, stack order) to every element in
  /// [ids].
  const PasteEffectsCommand({required this.ids, required this.effects});

  /// The elements gaining the stack.
  final List<String> ids;

  /// The pasted effects, in the order they were copied.
  final List<Map<String, Object?>> effects;

  @override
  EditorDocument apply(EditorDocument document) {
    var next = document;
    for (final id in ids) {
      for (final effect in effects) {
        next = next.addEffect(id, effect);
      }
    }
    return next;
  }

  @override
  String get label =>
      'Paste effects onto ${ids.length == 1 ? ids.single : '${ids.length} elements'}';

  @override
  Set<String> get affectedIds => {...ids};
}

/// Removes one effect from an element's stack.
final class RemoveEffectCommand extends EditorCommand {
  /// Removes effect [index] of element [id].
  const RemoveEffectCommand({required this.id, required this.index});

  /// The element losing the effect.
  final String id;

  /// Which `effects` entry goes.
  final int index;

  @override
  EditorDocument apply(EditorDocument document) => document.removeEffect(id, index);

  @override
  String get label => 'Remove effect of $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Moves one effect to a new place in its element's stack.
///
/// Order is meaning here: the stack composes by class then list order, so
/// reordering two same-class effects changes the picture, and the command
/// exists so that change is one undo step.
final class ReorderEffectCommand extends EditorCommand {
  /// Moves effect [from] of element [id] to index [to].
  const ReorderEffectCommand({required this.id, required this.from, required this.to});

  /// The element whose stack reorders.
  final String id;

  /// The effect's current index.
  final int from;

  /// Where it lands.
  final int to;

  @override
  EditorDocument apply(EditorDocument document) => document.reorderEffect(id, from, to);

  @override
  String get label => 'Reorder effects of $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Turns one effect on or off without touching its parameters.
final class SetEffectEnabledCommand extends EditorCommand {
  /// Sets effect [index] of element [id] to [enabled].
  const SetEffectEnabledCommand({required this.id, required this.index, required this.enabled});

  /// The element carrying the effect.
  final String id;

  /// Which `effects` entry toggles.
  final int index;

  /// Whether it runs. On is the default, so the document only says off.
  final bool enabled;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.updateEffect(id, index, {'enabled': enabled ? null : false});

  @override
  String get label => '${enabled ? 'Enable' : 'Disable'} effect of $id';

  @override
  Set<String> get affectedIds => {id};
}

/// Writes one effect parameter: a number from the field, a keyframed map
/// from the stopwatch turning on, a literal from the stopwatch turning off,
/// or null to fall back to the effect's own default.
final class SetEffectParamCommand extends EditorCommand {
  /// Sets parameter [param] of effect [index] on element [id] to [value].
  /// A non-null [mergeGroup] coalesces a slider scrub into one undo step.
  const SetEffectParamCommand({
    required this.id,
    required this.index,
    required this.param,
    required this.value,
    this.mergeGroup,
  });

  /// The element carrying the effect.
  final String id;

  /// Which `effects` entry holds the parameter.
  final int index;

  /// The parameter's name.
  final String param;

  /// The new value in document form, or null to clear it.
  final Object? value;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.updateEffect(id, index, {param: value});

  @override
  String get label => 'Set $param of $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'fx-param:$mergeGroup:$id:$index:$param';
}
