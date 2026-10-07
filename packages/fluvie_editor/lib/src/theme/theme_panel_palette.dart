part of 'theme_panel.dart';

/// A token name: a letter, then letters or digits (the spec's rule).
final RegExp _tokenName = RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$');

/// The palette half of the [ThemePanel]: one row per named color — rename
/// field, swatch, remove — plus the add button.
extension _ThemePanelPalette on ThemePanel {
  List<Widget> _paletteSection(
    BuildContext context,
    List<Color> recents,
    ValueChanged<Color> onPicked,
  ) => [
    for (final entry in _tokenMap('palette').entries)
      Padding(
        key: ValueKey('palette-${entry.key}'),
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                label: 'Rename ${entry.key}',
                child: InspectorTextField(
                  value: entry.key,
                  onChanged: (next) => _rename('palette', entry.key, next),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 40,
              child: ColorField(
                label: '${entry.key} color',
                color: _paletteColor(entry.value),
                recents: recents,
                onCommitted: onPicked,
                onChanged: (next) => _set(
                  _with('palette', entry.key, encodeColor(next)),
                  mergeGroup: 'palette-${entry.key}',
                ),
              ),
            ),
            EditorTip(
              message: document.themeTokenReferenced(entry.key)
                  ? 'In use somewhere in the deck'
                  : 'Remove color',
              child: OiIconButton(
                icon: OiIcons.trash,
                semanticLabel: 'Remove ${entry.key}',
                size: OiButtonSize.small,
                onTap: document.themeTokenReferenced(entry.key)
                    ? null
                    : () => _set(_with('palette', entry.key, null)),
              ),
            ),
          ],
        ),
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: EditorTip(
        message: 'Add color',
        child: OiIconButton(
          icon: OiIcons.plus,
          semanticLabel: 'Add color',
          size: OiButtonSize.small,
          onTap: () => _set(_with('palette', _mintedName(), '#6C5CE7')),
        ),
      ),
    ),
  ];

  Color _paletteColor(Object? raw) =>
      raw is String ? decodeColor(raw, path: const ['theme', 'palette']) : const Color(0xFF6C5CE7);

  /// The first free `colorN` name.
  String _mintedName() {
    final taken = _takenNames;
    var n = 1;
    while (taken.contains('color$n')) {
      n++;
    }
    return 'color$n';
  }

  /// Renames a token when the new name is a valid, free identifier; the
  /// command rewrites every bound reference in the same undo step.
  void _rename(String map, String from, String to) {
    if (to == from || !_tokenName.hasMatch(to) || _takenNames.contains(to)) return;
    onCommand(RenameThemeTokenCommand(map: map, from: from, to: to));
  }
}
