import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/commands/command_registry.dart';
import 'package:fluvie_editor/src/commands/command_scope.dart';
import 'package:obers_ui/obers_ui.dart';

/// The document flows a menu bar needs that are not editor commands: they act
/// on the file and the session rather than on the open document, so they have
/// no `CommandScope` to run against.
///
/// Every entry is nullable and a null one is offered disabled rather than
/// hidden, so the menu's shape never changes under you and an unavailable
/// render can say why through the note beside it.
typedef EditorFileActions = ({
  VoidCallback? save,
  VoidCallback? saveAs,
  VoidCallback? saveCopy,
  VoidCallback? exportDart,
  VoidCallback? exportImages,
  VoidCallback? exportPdf,
  VoidCallback? exportVideo,
  String? videoExportNote,
  VoidCallback? present,
  VoidCallback? close,
});

/// The editor's menu bar: File and Help from the host's own flows, Edit and
/// Arrange straight from the command registry.
///
/// Every command-backed item reads one registry entry for its label, its
/// shortcut hint, whether it is enabled and what it does, so a menu can never
/// advertise a binding that does not fire. That is the same guarantee the
/// context menus and the palette already have; this puts the top bar's loose
/// buttons under it too.
final class EditorMenuBar extends StatelessWidget {
  /// Builds the bar for [scope] with the host's [files] flows.
  const EditorMenuBar({required this.scope, required this.files, super.key});

  /// The document scope every command-backed item runs against.
  final CommandScope scope;

  /// The file and session flows that are not editor commands.
  final EditorFileActions files;

  @override
  Widget build(BuildContext context) =>
      OiMenuBar(label: 'Editor menu', items: editorMenuBarItems(scope, files));
}

/// The bar's top-level menus, in order.
///
/// Split out from the widget so a test can read the tree without mounting it,
/// which is what keeps the registry sweep cheap enough to run over every entry.
List<OiMenuItem> editorMenuBarItems(CommandScope scope, EditorFileActions files) => [
  OiMenuItem(label: 'File', children: _fileItems(files)),
  OiMenuItem(label: 'Edit', children: _commandItems(_editIds, scope)),
  OiMenuItem(label: 'Clip', children: _commandItems(_clipIds, scope)),
  OiMenuItem(label: 'Sequence', children: _commandItems(_sequenceIds, scope)),
  OiMenuItem(label: 'Arrange', children: _commandItems(_arrangeIds, scope)),
  // "Deck", not "Slide": the inspector already labels a section Slide, and
  // two surfaces with one name is ambiguous for a reader as well as a finder.
  OiMenuItem(label: 'Deck', children: _commandItems(_slideIds, scope)),
];

/// The registry ids each menu offers, in the order they are shown.
///
/// Ids rather than entries so the list stays readable and a typo fails loudly:
/// `editorCommandById` throws on an id the registry does not know.
const List<String?> _editIds = [
  'edit.undo',
  'edit.redo',
  null,
  'edit.cut',
  'edit.copy',
  'edit.paste',
  'edit.duplicate',
  null,
  'edit.delete',
];

const List<String?> _clipIds = [
  'timeline.razor',
  'timeline.razorAll',
  null,
  'timeline.rippleDelete',
  'timeline.lift',
  'timeline.extract',
];
const List<String?> _sequenceIds = [
  'timeline.markIn',
  'timeline.markOut',
  'timeline.clearMarks',
  null,
  'timeline.goToIn',
  'timeline.goToOut',
  'timeline.previousEdit',
  'timeline.nextEdit',
  null,
  'timeline.snap',
  'timeline.addLane',
  'timeline.deleteLane',
];

const List<String?> _arrangeIds = [
  'order.forward',
  'order.backward',
  'order.front',
  'order.back',
  null,
  'arrange.group',
  'arrange.ungroup',
];

const List<String?> _slideIds = [
  'slide.add',
  'slide.duplicate',
  null,
  'slide.delete',
];

/// One menu's items: a registry-backed entry per id, a divider per null.
List<OiMenuItem> _commandItems(List<String?> ids, CommandScope scope) => [
  for (final id in ids)
    if (id == null) const OiMenuDivider() else _commandItem(id, scope),
];

/// A menu item that reads everything from the registry entry [id] — label,
/// binding hint, enabled state, check mark, destructiveness and action.
///
/// The same construction the context menus use, so the bar cannot drift from
/// them or from the keyboard.
OiMenuItem _commandItem(String id, CommandScope scope) {
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

/// The File menu: the flows that act on the file and the session.
List<OiMenuItem> _fileItems(EditorFileActions files) => [
  OiMenuItem(label: 'Save', enabled: files.save != null, onTap: files.save),
  OiMenuItem(label: 'Save as', enabled: files.saveAs != null, onTap: files.saveAs),
  OiMenuItem(label: 'Save a copy', enabled: files.saveCopy != null, onTap: files.saveCopy),
  const OiMenuDivider(),
  OiMenuItem(label: 'Export Dart', enabled: files.exportDart != null, onTap: files.exportDart),
  OiMenuItem(
    label: 'Export slide images',
    enabled: files.exportImages != null,
    onTap: files.exportImages,
  ),
  OiMenuItem(label: 'Export PDF', enabled: files.exportPdf != null, onTap: files.exportPdf),
  OiMenuItem(
    // A render this platform cannot run stays visible and says what is
    // missing, rather than vanishing and leaving the author to wonder.
    label: files.exportVideo != null
        ? 'Export video (MP4)'
        : 'Export video (${files.videoExportNote ?? 'unavailable'})',
    enabled: files.exportVideo != null,
    onTap: files.exportVideo,
  ),
  const OiMenuDivider(),
  OiMenuItem(label: 'Present', enabled: files.present != null, onTap: files.present),
  OiMenuItem(label: 'Close', enabled: files.close != null, onTap: files.close),
];
