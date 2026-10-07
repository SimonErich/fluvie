part of 'command_registry.dart';

/// The smart-block commands: one make-block command per block kind, and
/// the clear that leaves the Group and its real geometry behind.
final List<EditorCommandEntry> _blockCommands = [
  for (final kind in BlockKind.values) _makeBlock(kind),
  EditorCommandEntry(
    id: 'block.clear',
    title: 'Clear block',
    category: 'Block',
    menus: const {EditorMenu.element},
    enabled: (scope) => _selectedBlocks(scope).isNotEmpty,
    execute: (scope) async {
      final ids = _selectedBlocks(scope);
      if (ids.isEmpty) return;
      scope.dispatch(ClearBlockCommand(ids: ids));
    },
  ),
];

/// Wraps the top-level selection into a new [kind] block at its bounding
/// box — the same wrap `arrange.group` performs, plus the block tag and the
/// first reflow, in one undo step.
EditorCommandEntry _makeBlock(BlockKind kind) => EditorCommandEntry(
  id: 'block.${kind.name}',
  title: 'Make ${kind.label} block',
  category: 'Block',
  menus: const {EditorMenu.element},
  enabled: (scope) => scope.enteredGroup == null && _topLevelSelection(scope).length >= 2,
  execute: (scope) async {
    final ids = _topLevelSelection(scope);
    if (ids.length < 2) return;
    Rect? union;
    for (final id in ids) {
      final rect = scope.rectOf(id);
      if (rect == null) return;
      union = union == null ? rect : union.expandToInclude(rect);
    }
    final canvas = scope.canvasSize;
    final groupId = scope.document.nextId();
    scope.dispatch(
      MakeBlockCommand(
        scene: scope.slide,
        ids: ids,
        groupId: groupId,
        transform: {
          'x': union!.center.dx / canvas.width,
          'y': union.center.dy / canvas.height,
          'w': union.width / canvas.width,
          'h': union.height / canvas.height,
        },
        block: BlockSpec.defaults(kind),
      ),
    );
    scope.select({groupId});
  },
);

/// The selected ids that are block groups, in z-order.
List<String> _selectedBlocks(CommandScope scope) => [
  for (final id in scope.orderedSelection)
    if (scope.document.blockOf(id) != null) id,
];
