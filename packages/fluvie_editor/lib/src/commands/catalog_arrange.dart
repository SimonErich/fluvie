part of 'command_registry.dart';

/// The arrange commands: z-order, group and ungroup, lock and hide, and
/// the align and distribute family (E17's commands finally get their
/// surface).
final List<EditorCommandEntry> _arrangeCommands = [
  _order(
    'order.forward',
    'Bring forward',
    ArrangeOrder.forward,
    const EditorShortcut(LogicalKeyboardKey.bracketRight),
  ),
  _order(
    'order.backward',
    'Send backward',
    ArrangeOrder.backward,
    const EditorShortcut(LogicalKeyboardKey.bracketLeft),
  ),
  _order(
    'order.front',
    'Bring to front',
    ArrangeOrder.front,
    const EditorShortcut(LogicalKeyboardKey.bracketRight, command: true),
  ),
  _order(
    'order.back',
    'Send to back',
    ArrangeOrder.back,
    const EditorShortcut(LogicalKeyboardKey.bracketLeft, command: true),
  ),
  EditorCommandEntry(
    id: 'arrange.group',
    title: 'Group',
    category: 'Arrange',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyG, command: true),
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
        GroupElementsCommand(
          scene: scope.slide,
          ids: ids,
          groupId: groupId,
          transform: {
            'x': union!.center.dx / canvas.width,
            'y': union.center.dy / canvas.height,
            'w': union.width / canvas.width,
            'h': union.height / canvas.height,
          },
        ),
      );
      scope.select({groupId});
    },
  ),
  EditorCommandEntry(
    id: 'arrange.ungroup',
    title: 'Ungroup',
    category: 'Arrange',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyG, command: true, shift: true),
    menus: const {EditorMenu.element},
    enabled: (scope) => _selectedGroups(scope).isNotEmpty,
    execute: (scope) async {
      final groups = _selectedGroups(scope);
      if (groups.isEmpty) return;
      final children = {
        for (final id in groups) ...scope.document.childIdsOfGroup(id),
      };
      if (groups.contains(scope.enteredGroup)) scope.exitGroup();
      scope.dispatch(UngroupElementsCommand(ids: groups));
      scope.select(children);
    },
  ),
  _align('align.left', 'Align left', AlignEdge.left),
  _align('align.centerX', 'Align center', AlignEdge.centerX),
  _align('align.right', 'Align right', AlignEdge.right),
  _align('align.top', 'Align top', AlignEdge.top),
  _align('align.centerY', 'Align middle', AlignEdge.centerY),
  _align('align.bottom', 'Align bottom', AlignEdge.bottom),
  _distribute('distribute.horizontal', 'Distribute horizontally', Axis.horizontal),
  _distribute('distribute.vertical', 'Distribute vertically', Axis.vertical),
  EditorCommandEntry(
    id: 'object.lock',
    title: 'Lock',
    category: 'Object',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyL, command: true, shift: true),
    menus: const {EditorMenu.element},
    checked: (scope) => scope.selection.isNotEmpty && scope.selection.every(scope.isLocked),
    enabled: (scope) => scope.selection.isNotEmpty,
    execute: (scope) async {
      final ids = scope.orderedSelection;
      if (ids.isEmpty) return;
      final locked = scope.selection.every(scope.isLocked);
      scope.dispatch(SetElementsMetaCommand(ids: ids, meta: {'locked': !locked}));
    },
  ),
  EditorCommandEntry(
    id: 'object.hide',
    title: 'Hide',
    category: 'Object',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyH, command: true, shift: true),
    menus: const {EditorMenu.element},
    checked: (scope) => scope.selection.isNotEmpty && scope.selection.every(scope.isHidden),
    enabled: (scope) => scope.selection.isNotEmpty,
    execute: (scope) async {
      final ids = scope.orderedSelection;
      if (ids.isEmpty) return;
      final hidden = scope.selection.every(scope.isHidden);
      scope.dispatch(SetElementsVisibleCommand(ids: ids, visible: hidden));
    },
  ),
];

/// The selected ids that live at the slide's top level, in z-order.
List<String> _topLevelSelection(CommandScope scope) => [
  for (final id in scope.document.elementIdsInScene(scope.slide))
    if (scope.selection.contains(id)) id,
];

/// The selected ids that are groups.
List<String> _selectedGroups(CommandScope scope) => [
  for (final id in scope.selection)
    if (scope.document.elementJson(id)?['type'] == 'Group') id,
];

EditorCommandEntry _order(String id, String title, ArrangeOrder order, EditorShortcut shortcut) =>
    EditorCommandEntry(
      id: id,
      title: title,
      category: 'Arrange',
      shortcut: shortcut,
      menus: const {EditorMenu.element},
      enabled: (scope) => scope.selection.isNotEmpty,
      execute: (scope) async {
        final ids = scope.orderedSelection;
        if (ids.isEmpty) return;
        scope.dispatch(ArrangeOrderCommand(ids: ids, order: order));
      },
    );

EditorCommandEntry _align(String id, String title, AlignEdge edge) => EditorCommandEntry(
  id: id,
  title: title,
  category: 'Align',
  menus: const {EditorMenu.element},
  enabled: (scope) => scope.selection.isNotEmpty,
  execute: (scope) async {
    final rects = _selectionRects(scope);
    if (rects == null) return;
    scope.dispatch(AlignElementsCommand(rects: rects, edge: edge, frame: scope.frameSize));
  },
);

EditorCommandEntry _distribute(String id, String title, Axis axis) => EditorCommandEntry(
  id: id,
  title: title,
  category: 'Align',
  menus: const {EditorMenu.element},
  enabled: (scope) => scope.selection.length >= 3,
  execute: (scope) async {
    final rects = _selectionRects(scope);
    if (rects == null || rects.length < 3) return;
    scope.dispatch(DistributeElementsCommand(rects: rects, axis: axis, frame: scope.frameSize));
  },
);

/// The selection's resolved rects in frame-local pixels (what the align
/// commands carry), or null while any element's size is still unknown.
Map<String, Rect>? _selectionRects(CommandScope scope) {
  final rects = <String, Rect>{};
  for (final id in scope.orderedSelection) {
    final rect = scope.rectOf(id);
    if (rect == null) return null;
    rects[id] = rect.shift(-scope.frameOrigin);
  }
  return rects.isEmpty ? null : rects;
}
