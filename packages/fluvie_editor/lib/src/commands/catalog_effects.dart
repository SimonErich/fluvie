part of 'command_registry.dart';

/// The effect-stack clipboard verbs: copy one selected element's stack,
/// paste an effects envelope onto every selected element. Copy reads the
/// z-order-first selected element that has effects, so a marquee that
/// caught three things still copies something predictable; paste fans out
/// as one undo step, which is how a look lands on five clips at once.
final List<EditorCommandEntry> _effectsCommands = [
  EditorCommandEntry(
    id: 'effect.copy',
    title: 'Copy Effects',
    category: 'Effects',
    menus: const {EditorMenu.element},
    enabled: (scope) =>
        scope.clipboard != null &&
        scope.orderedSelection.any((id) => _effectsOf(scope, id).isNotEmpty),
    execute: (scope) async {
      for (final id in scope.orderedSelection) {
        final effects = _effectsOf(scope, id);
        if (effects.isEmpty) continue;
        await scope.clipboard?.write(ClipboardEnvelope.effects(effects));
        return;
      }
    },
  ),
  EditorCommandEntry(
    id: 'effect.paste',
    title: 'Paste Effects',
    category: 'Effects',
    menus: const {EditorMenu.element},
    enabled: (scope) => scope.clipboard != null && scope.selection.isNotEmpty,
    execute: (scope) async {
      final envelope = await scope.clipboard?.read();
      if (envelope == null || envelope.kind != 'effects' || envelope.effects.isEmpty) return;
      // A selection of things that are not document elements (a master fill,
      // a stale id) resolves to no targets; dispatching would record an
      // undo step that changes nothing.
      final ids = scope.orderedSelection;
      if (ids.isEmpty) return;
      scope.dispatch(PasteEffectsCommand(ids: ids, effects: envelope.effects));
    },
  ),
];

/// The selected element's effect stack, or empty when it has none.
List<Map<String, Object?>> _effectsOf(CommandScope scope, String id) {
  final effects = scope.document.elementJson(id)?['effects'];
  if (effects is! List) return const [];
  return [...effects.whereType<Map<String, Object?>>()];
}
