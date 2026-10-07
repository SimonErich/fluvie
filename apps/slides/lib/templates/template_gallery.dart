import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/templates/deck_templates.dart';
import 'package:slides/templates/palette_sketch.dart';

/// Opens the template gallery over [context] and resolves to the picked
/// template, or null when the gallery is dismissed.
Future<DeckTemplate?> showTemplateGallery(BuildContext context) => OiDialogShell.show<DeckTemplate>(
  context: context,
  semanticLabel: 'New from template',
  maxWidth: 560,
  minWidth: 320,
  builder: (close) => OiDialog.standard(
    label: 'New from template',
    title: 'New from template',
    content: TemplateGalleryList(templates: builtinDeckTemplates, onPick: close),
    actions: [OiButton.secondary(label: 'Cancel', onTap: () => close())],
    onClose: () => close(),
  ),
);

/// The gallery's body: templates grouped by purpose, each tile leading
/// with a small palette sketch of the theme it ships.
final class TemplateGalleryList extends StatelessWidget {
  /// Lists [templates]; a tap hands the pick to [onPick].
  const TemplateGalleryList({required this.templates, required this.onPick, super.key});

  /// The templates on offer, in gallery order.
  final List<DeckTemplate> templates;

  /// Receives the picked template.
  final void Function(DeckTemplate template) onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final purposes = <String>[];
    for (final template in templates) {
      if (!purposes.contains(template.purpose)) purposes.add(template.purpose);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final purpose in purposes) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: OiLabel.small(purpose, color: colors.textSubtle),
          ),
          for (final template in templates)
            if (template.purpose == purpose)
              OiListTile(
                title: template.name,
                subtitle: template.description,
                leading: PaletteSketch.swatches(deck: template.deck),
                onTap: () => onPick(template),
              ),
        ],
      ],
    );
  }
}
