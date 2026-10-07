/// Command routing, clipboard, history actions, and arrangement API.
library;

export '../arrange/align_math.dart' show AlignEdge, alignDeltas, distributeDeltas;
export '../arrange/arrange_order.dart' show ArrangeOrder, arrangedIds;
export '../arrange/group_math.dart' show absolutePlacementJson, groupRectIn, relativePlacementJson;
export '../commands/command_palette.dart' show EditorCommandPalette, paletteCommands;
export '../commands/command_registry.dart'
    show
        EditorCommandEntry,
        EditorMenu,
        editorCommandById,
        editorCommandForKey,
        editorCommands,
        razorableBars;
export '../commands/command_scope.dart' show CommandScope;
export '../commands/context_menu_host.dart' show ContextMenuHost;
export '../commands/copied_slide.dart' show CopiedSlide;
export '../commands/editor_clipboard.dart'
    show ClipboardEnvelope, EditorClipboard, editorClipboardProvider;
export '../commands/editor_shortcut.dart' show EditorShortcut;
export '../commands/history_actions.dart' show HistoryActions, historyActionsProvider;
export '../commands/history_keys.dart' show HistoryKeys;
export '../commands/menu_templates.dart'
    show canvasMenuItems, elementMenuItems, menuItemsFor, slideStripMenuItems;
export '../commands/paste_remint.dart' show remintedElements;
