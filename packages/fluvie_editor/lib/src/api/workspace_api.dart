/// Workspace chrome, inspector, notes, theme, and delivery API.
library;

export '../chrome/editor_toolbar.dart' show EditorToolbar;
export '../chrome/selection_toolbar.dart' show SelectionToolbar;
export '../export/render_queue.dart'
    show QueuedRender, RenderQueue, RenderQueueJob, RenderQueuePhase;
export '../inspector/animate_presets.dart'
    show animatePresetOptions, animationName, isAnimatePresetHeading;
export '../inspector/animate_section.dart' show AnimateSection;
export '../inspector/auto_animate_section.dart' show AutoAnimateSection;
export '../inspector/block_section.dart' show BlockSection;
export '../inspector/chart_data_forms.dart'
    show
        ChartDataForm,
        ChartFormChange,
        ChartFormPatch,
        ChartFormRefusal,
        chartDataFormOf,
        chartFormsFor,
        convertChartForm;
export '../inspector/editor_inspector.dart' show EditorInspector;
export '../inspector/inspector_text_field.dart' show InspectorTextField;
export '../inspector/keyframe_section.dart' show KeyframeSection;
export '../inspector/morph_section.dart' show MorphSection;
export '../inspector/slide_duration_section.dart' show SlideDurationSection;
export '../masters/master_edit_session.dart' show MasterEditSession;
export '../masters/master_editor.dart' show MasterEditor;
export '../masters/master_slot_overlay.dart'
    show MasterSlotOverlay, slotPrefersMedia, unfilledSlotRects;
export '../motion/animation_panel.dart' show AnimationPanel;
export '../notes/notes_editor.dart' show NotesEditor;
export '../notes/notes_merge.dart' show mergedSlideNotes;
export '../shell/editor_menu_bar.dart' show EditorFileActions, EditorMenuBar, editorMenuBarItems;
export '../shell/editor_shell.dart'
    show EditorShell, EditorShellBottomBand, editorShellSettingsNamespace;
export '../shell/editor_workspace.dart'
    show DisclosureLevel, EditorWorkspace, WorkspaceControl, WorkspaceScope;
export '../shell/inspector_tab_request.dart'
    show InspectorTabRequest, InspectorTabRequestController, inspectorTabRequestProvider;
export '../shell/inspector_tabs.dart' show InspectorTab, InspectorTabPlaceholder, InspectorTabs;
export '../shell/quick_start_hint.dart' show QuickStartHint, QuickStartStep, quickStartStep;
export '../theme/builtin_themes.dart' show builtinThemes;
export '../theme/recent_colors.dart' show RecentColorsController, recentColorsProvider;
export '../theme/theme_panel.dart' show ThemePanel;
export '../theme/token_color_scope.dart' show TokenColorScope, tokenColorScopeFor;
export '../titles/title_catalog.dart';
export '../titles/titles_panel.dart' show TitlesPanel;
