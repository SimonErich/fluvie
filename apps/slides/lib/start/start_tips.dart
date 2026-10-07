import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// The first-run card: four things worth knowing before the first deck.
///
/// The shell shows it only while the user has no recent decks and has not
/// dismissed it, so it never greets a returning user. Dismissing it is
/// remembered between sessions.
final class StartTips extends StatelessWidget {
  /// Creates the card; [onDismiss] persists the dismissal and
  /// [onOpenSamples] hands the reader the sample decks.
  const StartTips({required this.onDismiss, required this.onOpenSamples, super.key});

  /// Puts the card away for good.
  final VoidCallback onDismiss;

  /// Opens the samples and tutorials dialog.
  final VoidCallback onOpenSamples;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OiCard.outlined(
      padding: const EdgeInsets.all(20),
      title: const OiLabel.h4('New here?'),
      subtitle: OiLabel.small(
        'Four things worth knowing before your first deck.',
        color: colors.textMuted,
      ),
      trailing: OiIconButton(
        icon: OiIcons.x,
        semanticLabel: 'Dismiss the intro tips',
        size: OiButtonSize.small,
        onTap: onDismiss,
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OiButton.ghost(
            label: 'Open the samples',
            icon: OiIcons.graduationCap,
            size: OiButtonSize.small,
            onTap: onOpenSamples,
          ),
          const SizedBox(width: 8),
          OiButton.ghost(label: 'Got it', size: OiButtonSize.small, onTap: onDismiss),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TipRow(
            icon: OiIcons.layers,
            title: 'A scene is a slide',
            body: 'You build scenes on the canvas. Each scene becomes one slide when you present.',
          ),
          SizedBox(height: 14),
          _TipRow(
            icon: OiIcons.presentation,
            title: 'Present with the keyboard',
            body:
                'Arrows step through the deck. O opens the overview. S opens the speaker '
                'window. F goes fullscreen.',
          ),
          SizedBox(height: 14),
          _TipRow(
            icon: OiIcons.film,
            title: 'The same deck renders to video',
            body:
                'Export an MP4 from the editor. The slides you present are the frames you '
                'get.',
          ),
          SizedBox(height: 14),
          _TipRow(
            icon: OiIcons.graduationCap,
            title: 'Learn from the samples',
            body: 'Seven sample decks show builds, speaker notes, media, and a full talk.',
          ),
        ],
      ),
    );
  }
}

/// One tip: an accent icon, a title, and a sentence.
final class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OiIcon.decorative(icon: icon, size: 18, color: colors.accent.base),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              OiLabel.smallStrong(title),
              const SizedBox(height: 2),
              OiLabel.tiny(body, color: colors.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}
