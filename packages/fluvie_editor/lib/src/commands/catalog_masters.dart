part of 'command_registry.dart';

/// The master commands: create a starter master, open master-edit mode for
/// the slide's adopted master, and detach a slide (its fills promote to
/// plain children). Applying a master by name lives on the slide strip's
/// masters row — a per-name pick has no stable registry identity.
final List<EditorCommandEntry> _masterCommands = [
  EditorCommandEntry(
    id: 'master.new',
    title: 'New master',
    category: 'Masters',
    menus: const {EditorMenu.slideStrip},
    enabled: (_) => true,
    execute: (scope) async {
      final name = _mintMasterName(scope.document);
      scope.dispatch(SetMasterCommand(name: name, master: _starterMaster, verb: 'Add'));
      scope.editMaster(name);
    },
  ),
  EditorCommandEntry(
    id: 'master.edit',
    title: 'Edit master',
    category: 'Masters',
    menus: const {EditorMenu.slideStrip},
    enabled: (scope) => scope.document.sceneMasterName(scope.slide) != null,
    execute: (scope) async {
      final name = scope.document.sceneMasterName(scope.slide);
      if (name != null) scope.editMaster(name);
    },
  ),
  EditorCommandEntry(
    id: 'master.detach',
    title: 'Detach master',
    category: 'Masters',
    menus: const {EditorMenu.slideStrip},
    enabled: (scope) => scope.document.sceneMasterName(scope.slide) != null,
    execute: (scope) async {
      if (scope.document.sceneMasterName(scope.slide) == null) return;
      scope.dispatch(DetachMasterCommand(slide: scope.slide));
    },
  ),
];

/// The starter layout a fresh master begins with: a title and a body slot.
const Map<String, Object?> _starterMaster = {
  'children': [
    {
      'type': 'Placeholder',
      'slot': 'title',
      'transform': {'x': 0.5, 'y': 0.22, 'w': 0.8, 'h': 0.18},
    },
    {
      'type': 'Placeholder',
      'slot': 'body',
      'transform': {'x': 0.5, 'y': 0.6, 'w': 0.8, 'h': 0.5},
    },
  ],
};

/// The first free `masterN` name (master names are identifiers).
String _mintMasterName(EditorDocument document) {
  final taken = document.masterNames.toSet();
  var counter = 1;
  while (taken.contains('master$counter')) {
    counter++;
  }
  return 'master$counter';
}
