import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/templates/deck_templates.dart';
import 'package:slides/templates/palette_sketch.dart';

/// The template strip: one card per builtin template, plus a way into the
/// full gallery.
///
/// A card starts its deck straight away. The gallery is for browsing, not
/// for the common case.
final class StartTemplates extends StatelessWidget {
  /// Creates the strip; [onPick] starts a deck, [onBrowseAll] opens the
  /// gallery dialog.
  const StartTemplates({required this.onPick, required this.onBrowseAll, super.key});

  /// Starts a deck from the picked template.
  final void Function(DeckTemplate template) onPick;

  /// Opens the full template gallery.
  final VoidCallback onBrowseAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const OiLabel.h4('Templates'),
            const Spacer(),
            OiButton.ghost(
              label: 'Browse all',
              icon: OiIcons.layoutTemplate,
              size: OiButtonSize.small,
              onTap: onBrowseAll,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final template in builtinDeckTemplates)
              SizedBox(
                width: 172,
                child: OiCard.interactive(
                  label: 'New deck from ${template.name}',
                  onTap: () => onPick(template),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PaletteSketch.slide(deck: template.deck, width: 148, height: 56),
                      const SizedBox(height: 10),
                      OiLabel.smallStrong(
                        template.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      OiLabel.tiny(template.description, color: colors.textMuted, maxLines: 2),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
