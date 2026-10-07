import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

/// The inspector's Morph row for a selected element on an auto-animated
/// slide: linked, it names the previous-slide partner and offers unlink;
/// unlinked, it offers a picker over the previous slide's unclaimed
/// elements. Manual links are author-level `shared` ids — they survive the
/// auto-animate toggle.
final class MorphSection extends StatelessWidget {
  /// Shows the pairing of element [id] on [slide]; commands land in
  /// [onCommand].
  const MorphSection({
    required this.document,
    required this.slide,
    required this.id,
    required this.onCommand,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide holding the selected element.
  final int slide;

  /// The selected element.
  final String id;

  /// Receives the link and unlink commands.
  final void Function(EditorCommand command) onCommand;

  /// What the row calls a previous-slide element: its editor name when the
  /// author gave it one, its id otherwise.
  String _labelOf(String elementId) =>
      (document.elementMeta(elementId)['name'] as String?) ?? elementId;

  @override
  Widget build(BuildContext context) {
    final partner = document.sharedPartnerOf(slide, id);
    if (partner != null) return _linkedRow(context, partner);
    final candidates = document.linkCandidatesOf(slide);
    if (candidates.isEmpty) {
      return OiLabel.small('No previous slide element to link', color: context.colors.textSubtle);
    }
    return OiSelect<String>(
      key: const ValueKey('morph-link-picker'),
      placeholder: 'Link to previous slide element',
      options: [
        for (final candidate in candidates)
          OiSelectOption(value: candidate, label: _labelOf(candidate)),
      ],
      onChanged: (picked) {
        if (picked == null) return;
        onCommand(LinkSharedCommand(slide: slide, currentId: id, previousId: picked));
      },
    );
  }

  Widget _linkedRow(BuildContext context, String partner) => Row(
    children: [
      Expanded(
        child: OiLabel.small('Morphs from ${_labelOf(partner)}', color: context.colors.textSubtle),
      ),
      EditorTip(
        message: 'Unlink from the previous slide',
        child: OiIconButton(
          icon: OiIcons.x,
          semanticLabel: 'Unlink from the previous slide',
          onTap: () => onCommand(UnlinkSharedCommand(slide: slide, elementId: id)),
        ),
      ),
    ],
  );
}
