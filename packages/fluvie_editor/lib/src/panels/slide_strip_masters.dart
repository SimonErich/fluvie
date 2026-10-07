part of 'slide_strip.dart';

/// The strip's masters row: every master by name with apply-to-current and
/// edit affordances. Rendered only while the deck defines masters; the
/// first master arrives through the tile menu's New master (or a template).
extension _SlideStripMasters on _SlideStripState {
  Widget _mastersRow(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OiLabel.small('Masters', color: colors.textSubtle),
          for (final name in widget.document.masterNames)
            Row(
              children: [
                Expanded(child: OiLabel.small(name, color: colors.text)),
                EditorTip(
                  message: 'Apply to this slide',
                  child: OiIconButton(
                    icon: OiIcons.check,
                    semanticLabel: 'Apply master $name to this slide',
                    onTap: widget.document.sceneMasterName(widget.current) == name
                        ? null
                        : () => widget.onCommand(
                            ApplyMasterCommand(slide: widget.current, name: name),
                          ),
                  ),
                ),
                if (widget.onEditMaster != null)
                  EditorTip(
                    message: 'Edit master',
                    child: OiIconButton(
                      icon: OiIcons.pencil,
                      semanticLabel: 'Edit master $name',
                      onTap: () => widget.onEditMaster!(name),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
