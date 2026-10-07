import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorTip, editorCommandById;
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/export_menu.dart';
import 'package:slides/editor/renamable_title.dart';

/// The editor's top bar: close, the deck name with its saved indicator,
/// undo/redo, present, save, the export menu, and the slide stepper.
final class EditorTopBar extends StatelessWidget {
  /// Creates the bar.
  const EditorTopBar({
    required this.name,
    required this.onRenamed,
    required this.saveStatus,
    required this.saveAttention,
    required this.canUndo,
    required this.canRedo,
    required this.slide,
    required this.sceneCount,
    required this.onClose,
    required this.onUndo,
    required this.onRedo,
    required this.onPresent,
    required this.onSave,
    required this.onSaveAs,
    required this.onSaveCopy,
    required this.onExportDart,
    required this.onExportImages,
    required this.onExportPdf,
    required this.onExportVideo,
    required this.onStep,
    this.videoUnavailableNote = 'needs the desktop app',
    this.mode = 'slides',
    this.onMode,
    this.menuBar,
    this.workspaceControl,
    super.key,
  });

  /// The deck's file name.
  final String name;

  /// Receives an inline rename of the deck (double-click the name).
  final ValueChanged<String> onRenamed;

  /// The quiet saved indicator's text ("Saved", "Unsaved",
  /// "Autosaved just now", "Saving…").
  final String saveStatus;

  /// Whether the indicator warrants the warning tone (changes not covered
  /// by any save or autosave yet).
  final bool saveAttention;

  /// Whether an undo step exists.
  final bool canUndo;

  /// Whether a redo step exists.
  final bool canRedo;

  /// The slide on stage (zero-based).
  final int slide;

  /// How many slides the deck has.
  final int sceneCount;

  /// Leaves the editor (the guard runs upstream).
  final VoidCallback onClose;

  /// Undoes one step.
  final VoidCallback onUndo;

  /// Redoes one step.
  final VoidCallback onRedo;

  /// Presents the current document.
  final VoidCallback onPresent;

  /// Saves to the remembered target.
  final VoidCallback onSave;

  /// The workspace picker, mounted beside the menu bar.
  ///
  /// Supplied by the host for the same reason as [menuBar]: it is view state
  /// the screen owns, not something the bar should hold.
  final Widget? workspaceControl;

  /// The document menu bar, mounted under the title row.
  ///
  /// Supplied by the host rather than built here: it reads the command
  /// registry against the live scope, which the top bar has no business
  /// knowing about.
  final Widget? menuBar;

  /// Saves to a newly picked target (also the menu's "Export .fluvie").
  final VoidCallback onSaveAs;

  /// Saves a copy to a newly picked target without retargeting the open
  /// document.
  final VoidCallback onSaveCopy;

  /// Writes the printed Dart source through the copy channel.
  final VoidCallback onExportDart;

  /// Renders every slide's settled state to a PNG.
  final VoidCallback onExportImages;

  /// Renders every slide's settled state into one PDF, a page per slide.
  final VoidCallback onExportPdf;

  /// Renders the deck to an MP4, or null where the platform cannot (the
  /// menu entry then explains [videoUnavailableNote]).
  final VoidCallback? onExportVideo;

  /// The render service's reason shown on the disabled video entry.
  final String videoUnavailableNote;

  /// Steps the stage by plus or minus one slide.
  final void Function(int delta) onStep;

  /// The editing mode on stage: `slides` or `video`.
  final String mode;

  /// Receives a mode pick from the toggle; null hides the toggle.
  final ValueChanged<String>? onMode;

  /// One document, two lenses: the compact mode toggle. The tooltips carry
  /// the honest cross-mode statement — nothing drops on a switch,
  /// slides-only concepts simply keep living in Slides mode.
  Widget _modeToggle() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      EditorTip(
        message: 'Slides mode: one slide at a time, steps, notes, animation',
        child: OiIconButton(
          icon: OiIcons.presentation,
          semanticLabel: 'Slides mode',
          variant: mode == 'slides' ? OiButtonVariant.secondary : OiButtonVariant.ghost,
          onTap: () => onMode!('slides'),
        ),
      ),
      EditorTip(
        message:
            'Video mode: the whole composition in time. Steps, notes, and '
            'per-slide animation stay as authored in Slides mode.',
        child: OiIconButton(
          icon: OiIcons.film,
          semanticLabel: 'Video mode',
          variant: mode == 'video' ? OiButtonVariant.secondary : OiButtonVariant.ghost,
          onTap: () => onMode!('video'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bar = menuBar;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                EditorTip(
                  message: 'Close editor (guarded while unsaved)',
                  child: OiIconButton(
                    icon: OiIcons.x,
                    semanticLabel: 'Close editor',
                    onTap: onClose,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: RenamableTitle(name: name, onRenamed: onRenamed),
                      ),
                      const SizedBox(width: 8),
                      OiLabel.small(
                        saveStatus,
                        color: saveAttention ? colors.warning.base : colors.textMuted,
                      ),
                    ],
                  ),
                ),
                // The chord hints come from the registry, so a tooltip can never
                // advertise a binding that does not fire.
                EditorTip(
                  message: 'Undo the last step (${editorCommandById('edit.undo').shortcut!.hint})',
                  child: OiIconButton(
                    icon: OiIcons.undo,
                    semanticLabel: 'Undo',
                    onTap: canUndo ? onUndo : null,
                  ),
                ),
                EditorTip(
                  message:
                      'Redo the undone step (${editorCommandById('edit.redo').shortcut!.hint})',
                  child: OiIconButton(
                    icon: OiIcons.redo,
                    semanticLabel: 'Redo',
                    onTap: canRedo ? onRedo : null,
                  ),
                ),
                const SizedBox(width: 8),
                if (onMode != null) ...[_modeToggle(), const SizedBox(width: 4)],
                OiButton.primary(label: 'Present', onTap: onPresent),
                const SizedBox(width: 4),
                // Save keeps a button because it is the one action reached dozens
                // of times an hour; everything else it used to sit beside now
                // lives in the File menu, where the bar can also show its binding.
                OiButton.secondary(label: 'Save', onTap: onSave),
                const SizedBox(width: 4),
                ExportMenu(
                  onExportFluvie: onSaveAs,
                  onExportDart: onExportDart,
                  onExportImages: onExportImages,
                  onExportPdf: onExportPdf,
                  onExportVideo: onExportVideo,
                  videoUnavailableNote: videoUnavailableNote,
                ),
                const SizedBox(width: 8),
                EditorTip(
                  message: 'Previous slide',
                  child: OiIconButton(
                    icon: OiIcons.chevronLeft,
                    semanticLabel: 'Previous slide',
                    onTap: () => onStep(-1),
                  ),
                ),
                OiLabel.small('${slide + 1} / $sceneCount', color: colors.textSubtle),
                EditorTip(
                  message: 'Next slide',
                  child: OiIconButton(
                    icon: OiIcons.chevronRight,
                    semanticLabel: 'Next slide',
                    onTap: () => onStep(1),
                  ),
                ),
              ],
            ),
          ),
          // The workspace picker rides the menu row, not the title row: the
          // title row is already the busiest strip in the app, and a five-way
          // control belongs beside the menus it re-scopes.
          if (bar != null || workspaceControl != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: Row(
                children: [
                  if (bar != null) Expanded(child: bar) else const Spacer(),
                  ?workspaceControl,
                ],
              ),
            ),
        ],
      ),
    );
  }
}
