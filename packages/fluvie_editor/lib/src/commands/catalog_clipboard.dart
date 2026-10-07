part of 'command_registry.dart';

/// The clipboard and selection commands: cut, copy, paste, duplicate,
/// select all, and delete.
final List<EditorCommandEntry> _clipboardCommands = [
  EditorCommandEntry(
    id: 'edit.cut',
    title: 'Cut',
    category: 'Edit',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyX, command: true),
    menus: const {EditorMenu.element},
    enabled: (scope) => scope.selection.isNotEmpty && scope.clipboard != null,
    execute: (scope) async {
      final ids = scope.orderedSelection;
      if (ids.isEmpty) return;
      await _copySelection(scope);
      scope.dispatch(RemoveElementsCommand(ids: ids));
      scope.select(const {});
    },
  ),
  EditorCommandEntry(
    id: 'edit.copy',
    title: 'Copy',
    category: 'Edit',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyC, command: true),
    menus: const {EditorMenu.element},
    enabled: (scope) => scope.selection.isNotEmpty && scope.clipboard != null,
    execute: _copySelection,
  ),
  EditorCommandEntry(
    id: 'edit.paste',
    title: 'Paste',
    category: 'Edit',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyV, command: true),
    menus: const {EditorMenu.element, EditorMenu.canvas},
    enabled: (scope) => scope.clipboard != null,
    execute: (scope) async {
      final envelope = await scope.clipboard?.read();
      if (envelope == null || envelope.elements.isEmpty) return;
      final slideIds = _allIdsInScene(scope.document, scope.slide);
      _insertReminted(
        scope,
        envelope.elements,
        verb: 'Paste',
        nudge: envelope.sourceIds.intersection(slideIds).isNotEmpty,
      );
    },
  ),
  EditorCommandEntry(
    id: 'edit.duplicate',
    title: 'Duplicate',
    category: 'Edit',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyD, command: true),
    menus: const {EditorMenu.element},
    enabled: (scope) => scope.selection.isNotEmpty,
    execute: (scope) async {
      final elements = [
        for (final id in scope.orderedSelection) scope.document.elementJson(id)!,
      ];
      if (elements.isEmpty) return;
      _insertReminted(scope, elements, verb: 'Duplicate', nudge: true);
    },
  ),
  EditorCommandEntry(
    id: 'edit.selectAll',
    title: 'Select all',
    category: 'Edit',
    shortcut: const EditorShortcut(LogicalKeyboardKey.keyA, command: true),
    menus: const {EditorMenu.canvas},
    enabled: (scope) => _selectable(scope).isNotEmpty,
    execute: (scope) async => scope.select({..._selectable(scope)}),
  ),
  EditorCommandEntry(
    id: 'edit.delete',
    title: 'Delete',
    category: 'Edit',
    shortcut: const EditorShortcut(
      LogicalKeyboardKey.delete,
      also: [LogicalKeyboardKey.backspace],
    ),
    menus: const {EditorMenu.element},
    destructive: true,
    enabled: (scope) => scope.selection.isNotEmpty,
    execute: (scope) async {
      // Fills join the delete: removing one unfills its slot (they stay off
      // the z-order surfaces, so the ordered selection alone misses them).
      final ids = [...scope.orderedSelection, ...scope.selectedFills];
      if (ids.isEmpty) return;
      scope.dispatch(RemoveElementsCommand(ids: ids));
      scope.select(const {});
    },
  ),
];

/// Writes the selection to the clipboard: element JSON in z-order, plus
/// every id inside the copied trees (the same-slide marker paste reads).
Future<void> _copySelection(CommandScope scope) async {
  final clipboard = scope.clipboard;
  if (clipboard == null) return;
  final elements = [
    for (final id in scope.orderedSelection) scope.document.elementJson(id)!,
  ];
  if (elements.isEmpty) return;
  await clipboard.write(
    ClipboardEnvelope(elements: elements, sourceIds: _idsWithin(elements)),
  );
}

/// Re-mints [elements] against the target document and inserts them as one
/// undo step, selecting the copies. Paste and duplicate share this tail.
///
/// The batch lands in the scope's frame: the slide's top level, or — with a
/// group entered — inside that group, transforms taken verbatim as
/// fractions of the frame (the same rule that carries a paste across canvas
/// sizes), a block target re-balancing the newcomers into slots. A pasted
/// Group never nests, though: with a group entered it lands at the slide's
/// top level beside it, the same one concept move and drag enforce. [nudge]
/// applies the small same-slide offset in frame pixels.
void _insertReminted(
  CommandScope scope,
  List<Map<String, Object?>> elements, {
  required String verb,
  required bool nudge,
}) {
  final document = scope.document;
  final fresh = document.nextIds(_idsWithin(elements).length).iterator;
  final reminted = remintedElements(
    elements,
    mintId: () => (fresh..moveNext()).current,
    mintAnchorId: _anchorMinter(document, elements),
  );
  if (nudge) {
    for (final element in reminted) {
      final transform = element['transform'];
      if (transform is Map<String, Object?>) {
        transform['x'] = ((transform['x'] as num?)?.toDouble() ?? 0.5) + 10 / scope.frameSize.width;
        transform['y'] =
            ((transform['y'] as num?)?.toDouble() ?? 0.5) + 10 / scope.frameSize.height;
      }
    }
  }
  scope.dispatch(
    InsertElementsCommand(
      scene: scope.slide,
      elements: reminted,
      verb: verb,
      group: scope.enteredGroup,
    ),
  );
  scope.select({
    for (final element in reminted)
      if (element['id'] case final String id) id,
  });
}

/// The ids the select-all command takes: the scope's elements minus the
/// locked and hidden ones (the same set the canvas lets you touch).
List<String> _selectable(CommandScope scope) => [
  for (final id in scope.scopeIds)
    if (!scope.isLocked(id) && !scope.isHidden(id)) id,
];

/// Every element id inside [elements], nested group children included.
Set<String> _idsWithin(List<Map<String, Object?>> elements) {
  final ids = <String>{};
  void walk(Map<String, Object?> element) {
    if (element['id'] case final String id) ids.add(id);
    final children = element['children'];
    if (element['type'] == 'Group' && children is List) {
      children.whereType<Map<String, Object?>>().forEach(walk);
    }
  }

  elements.forEach(walk);
  return ids;
}

/// The paste-policy anchor minter against [document]: an anchor re-mints
/// only on a collision with the target document (the first free `-2`, `-3`
/// suffix), consistently across the copied [elements] set; a paste into a
/// document that never saw the anchor keeps it verbatim.
String Function(String old) _anchorMinter(
  EditorDocument document,
  List<Map<String, Object?>> elements,
) {
  final documentAnchors = document.anchorIds;
  final usedAnchors = {...documentAnchors, ..._declaredAnchors(elements)};
  return (old) {
    if (!documentAnchors.contains(old)) return old;
    var suffix = 2;
    while (usedAnchors.contains('$old-$suffix')) {
      suffix++;
    }
    final minted = '$old-$suffix';
    usedAnchors.add(minted);
    return minted;
  };
}

/// Every anchor id declared inside [elements], nested children included.
Set<String> _declaredAnchors(List<Map<String, Object?>> elements) {
  final anchors = <String>{};
  void walk(Map<String, Object?> element) {
    if (element['anchor'] case final String anchor) anchors.add(anchor);
    final children = element['children'];
    if (element['type'] == 'Group' && children is List) {
      children.whereType<Map<String, Object?>>().forEach(walk);
    }
  }

  elements.forEach(walk);
  return anchors;
}

/// Every element id of scene [scene], nested group children included — the
/// same-slide test paste applies its nudge on.
Set<String> _allIdsInScene(EditorDocument document, int scene) {
  final ids = <String>{};
  void add(String id) {
    ids.add(id);
    document.childIdsOfGroup(id).forEach(add);
  }

  document.elementIdsInScene(scene).forEach(add);
  return ids;
}
