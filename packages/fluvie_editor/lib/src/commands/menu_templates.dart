/// The context-menu templates. Every item comes from the command registry —
/// label, shortcut hint, enabled state, and action all read one entry, so a
/// menu can never drift from the binding that fires (the registry sweep
/// pins it).
library;

import 'dart:async' show unawaited;

import 'package:fluvie_editor/src/commands/command_registry.dart';
import 'package:fluvie_editor/src/commands/command_scope.dart';
import 'package:obers_ui/obers_ui.dart' show OiMenuDivider, OiMenuItem;

/// The items of [menu] against [scope].
List<OiMenuItem> menuItemsFor(EditorMenu menu, CommandScope scope) => switch (menu) {
  EditorMenu.element => elementMenuItems(scope),
  EditorMenu.canvas => canvasMenuItems(scope),
  EditorMenu.slideStrip => slideStripMenuItems(scope),
  EditorMenu.timeline => timelineMenuItems(scope),
};

/// The right-click menu over the timeline: the verbs that act on time.
List<OiMenuItem> timelineMenuItems(CommandScope scope) => _joined([
  [
    for (final id in const ['timeline.markIn', 'timeline.markOut', 'timeline.clearMarks'])
      _item(id, scope),
  ],
  [
    for (final id in const ['timeline.goToIn', 'timeline.goToOut']) _item(id, scope),
  ],
  [
    for (final id in const ['timeline.previousEdit', 'timeline.nextEdit']) _item(id, scope),
  ],
  [
    for (final id in const [
      'timeline.razor',
      'timeline.razorAll',
      'timeline.rippleDelete',
      'timeline.lift',
      'timeline.extract',
    ])
      _item(id, scope),
  ],
  [
    for (final id in const ['timeline.snap', 'timeline.addLane', 'timeline.deleteLane'])
      _item(id, scope),
  ],
]);

/// The right-click menu over an element or a selection.
List<OiMenuItem> elementMenuItems(CommandScope scope) => _joined([
  [
    for (final id in const ['edit.cut', 'edit.copy', 'edit.paste', 'edit.duplicate'])
      _item(id, scope),
  ],
  [
    for (final id in const ['effect.copy', 'effect.paste']) _item(id, scope),
  ],
  [
    for (final id in const ['order.forward', 'order.backward', 'order.front', 'order.back'])
      _item(id, scope),
  ],
  [
    for (final id in const ['arrange.group', 'arrange.ungroup']) _item(id, scope),
  ],
  [_alignSubmenu(scope)],
  [_blockSubmenu(scope)],
  [
    for (final id in const ['object.lock', 'object.hide']) _item(id, scope),
  ],
  [_item('edit.delete', scope)],
]);

/// The right-click menu over empty canvas.
List<OiMenuItem> canvasMenuItems(CommandScope scope) => _joined([
  [
    for (final id in const ['edit.undo', 'edit.redo']) _item(id, scope),
  ],
  [
    for (final id in const ['edit.paste', 'edit.selectAll']) _item(id, scope),
  ],
  [
    for (final id in const ['slide.add', 'slide.duplicate', 'slide.delete']) _item(id, scope),
  ],
]);

/// The right-click menu on a slide-strip tile (the scope's slide is the
/// tile's index, not necessarily the one on stage).
List<OiMenuItem> slideStripMenuItems(CommandScope scope) => _joined([
  [
    for (final id in const ['slide.copy', 'slide.paste']) _item(id, scope),
  ],
  [
    for (final id in const ['slide.duplicate', 'slide.delete']) _item(id, scope),
  ],
  [_item('slide.section', scope)],
  [
    for (final id in const ['master.edit', 'master.detach', 'master.new']) _item(id, scope),
  ],
  [
    for (final id in const ['slide.moveUp', 'slide.moveDown']) _item(id, scope),
  ],
]);

OiMenuItem _alignSubmenu(CommandScope scope) => OiMenuItem(
  label: 'Align',
  children: [
    for (final id in const [
      'align.left',
      'align.centerX',
      'align.right',
      'align.top',
      'align.centerY',
      'align.bottom',
    ])
      _item(id, scope),
    const OiMenuDivider(),
    for (final id in const ['distribute.horizontal', 'distribute.vertical']) _item(id, scope),
  ],
);

OiMenuItem _blockSubmenu(CommandScope scope) => OiMenuItem(
  label: 'Block',
  children: [
    for (final id in const [
      'block.row',
      'block.column',
      'block.grid',
      'block.list',
      'block.split',
      'block.titleBody',
    ])
      _item(id, scope),
    const OiMenuDivider(),
    _item('block.clear', scope),
  ],
);

OiMenuItem _item(String id, CommandScope scope) {
  final entry = editorCommandById(id);
  final enabled = entry.enabled(scope);
  return OiMenuItem(
    label: entry.title,
    shortcut: entry.shortcut?.hint,
    enabled: enabled,
    checked: entry.checked?.call(scope),
    destructive: entry.destructive,
    onTap: enabled ? () => unawaited(entry.execute(scope)) : null,
  );
}

List<OiMenuItem> _joined(List<List<OiMenuItem>> sections) => [
  for (var i = 0; i < sections.length; i++) ...[
    if (i > 0) const OiMenuDivider(),
    ...sections[i],
  ],
];
