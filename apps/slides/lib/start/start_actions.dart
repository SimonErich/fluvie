import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// The action column: the two primary actions, then the secondary ones.
///
/// "Open a deck" opens the editor, because that is what a studio's open
/// command means. Presenting a file without editing it is one of the
/// secondary tiles, and the sample decks live behind another.
final class StartActions extends StatelessWidget {
  /// Creates the column; [compact] drops the filler that pins the hint line
  /// to the bottom of a full-height sidebar.
  const StartActions({
    required this.compact,
    required this.onNewDeck,
    required this.onOpenDeck,
    required this.onNewFromTemplate,
    required this.onPresentFile,
    required this.onOpenSamples,
    super.key,
  });

  /// Whether the column sits in the narrow, scrolling layout.
  final bool compact;

  /// Starts a blank deck in the editor.
  final VoidCallback onNewDeck;

  /// Opens a `.fluvie` file in the editor.
  final VoidCallback onOpenDeck;

  /// Opens the template gallery.
  final VoidCallback onNewFromTemplate;

  /// Opens a `.fluvie` file straight into the presenter.
  final VoidCallback onPresentFile;

  /// Opens the samples and tutorials dialog.
  final VoidCallback onOpenSamples;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        OiLabel.overline('START', color: colors.textMuted),
        const SizedBox(height: 12),
        OiButton.primary(
          label: 'New deck',
          icon: OiIcons.filePlus,
          size: OiButtonSize.large,
          fullWidth: true,
          onTap: onNewDeck,
        ),
        const SizedBox(height: 8),
        OiButton.secondary(
          label: 'Open a deck',
          icon: OiIcons.folderOpen,
          size: OiButtonSize.large,
          fullWidth: true,
          onTap: onOpenDeck,
        ),
        const SizedBox(height: 24),
        const OiDivider(),
        const SizedBox(height: 16),
        OiLabel.overline('MORE', color: colors.textMuted),
        const SizedBox(height: 4),
        OiListTile(
          leading: OiIcon.decorative(
            icon: OiIcons.layoutTemplate,
            size: 18,
            color: colors.textMuted,
          ),
          title: 'New from template',
          subtitle: 'Start from a purpose-built deck',
          onTap: onNewFromTemplate,
        ),
        OiListTile(
          leading: OiIcon.decorative(icon: OiIcons.monitorPlay, size: 18, color: colors.textMuted),
          title: 'Present a .fluvie file',
          subtitle: 'Play a deck without opening the editor',
          onTap: onPresentFile,
        ),
        OiListTile(
          leading: OiIcon.decorative(
            icon: OiIcons.graduationCap,
            size: 18,
            color: colors.textMuted,
          ),
          title: 'Samples and tutorials',
          subtitle: 'Seven decks that show what fluvie does',
          onTap: onOpenSamples,
        ),
        if (!compact) const Spacer(),
        const SizedBox(height: 16),
        OiLabel.tiny('Drop a .fluvie file anywhere to present it.', color: colors.textMuted),
      ],
    );
  }
}
