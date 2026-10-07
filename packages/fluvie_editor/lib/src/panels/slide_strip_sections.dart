part of 'slide_strip.dart';

/// The sectioned face of the strip: named headers over their tiles, with
/// collapse, inline rename, whole-section moves, and removal — every change
/// a document command, so it all undoes.
extension _SlideStripSections on _SlideStripState {
  /// The strip's rows while named sections exist: each header, then its
  /// tiles unless collapsed.
  List<Widget> _sectionedRows(List<DeckSection> sections) => [
    for (var i = 0; i < sections.length; i++) ...[
      if (sections[i].name case final String name)
        _SectionHeader(
          key: ValueKey('section-${sections[i].start}'),
          name: name,
          collapsed: sections[i].collapsed,
          onToggle: () => _toggleSection(sections[i]),
          onRenamed: (next) => _renameSection(sections[i], next),
          menuItems: _sectionMenu(sections, i),
        ),
      if (!sections[i].collapsed)
        for (var slide = sections[i].start; slide < sections[i].end; slide++) _tile(slide),
    ],
  ];

  /// The marker for [section] carrying [collapsed] (the name travels with
  /// every write because the meta key replaces as a whole).
  Map<String, Object?> _marker(DeckSection section, {String? name, bool? collapsed}) => {
    'section': {
      'name': name ?? section.name,
      if (collapsed ?? section.collapsed) 'collapsed': true,
    },
  };

  void _toggleSection(DeckSection section) => widget.onCommand(
    SetSceneMetaCommand(
      index: section.start,
      meta: _marker(section, collapsed: !section.collapsed),
    ),
  );

  void _renameSection(DeckSection section, String name) => widget.onCommand(
    SetSceneMetaCommand(
      index: section.start,
      meta: _marker(section, name: name),
    ),
  );

  /// The header's right-click menu: whole-section moves (a section never
  /// moves above the unsectioned leading run — those slides would be
  /// absorbed into it) and removal.
  List<OiMenuItem> _sectionMenu(List<DeckSection> sections, int index) {
    final section = sections[index];
    final previous = index > 0 ? sections[index - 1] : null;
    final next = index + 1 < sections.length ? sections[index + 1] : null;
    final above = previous != null && previous.name != null ? previous : null;
    return [
      OiMenuItem(
        label: 'Move section up',
        enabled: above != null,
        onTap: above == null
            ? null
            : () => widget.onCommand(
                ReorderSceneRangeCommand(
                  start: section.start,
                  count: section.count,
                  to: above.start,
                ),
              ),
      ),
      OiMenuItem(
        label: 'Move section down',
        enabled: next != null,
        onTap: next == null
            ? null
            : () => widget.onCommand(
                ReorderSceneRangeCommand(
                  start: section.start,
                  count: section.count,
                  to: section.start + next.count,
                ),
              ),
      ),
      const OiMenuDivider(),
      OiMenuItem(
        label: 'Remove section',
        destructive: true,
        onTap: () => widget.onCommand(
          SetSceneMetaCommand(index: section.start, meta: const {'section': null}),
        ),
      ),
    ];
  }
}

/// A named section's header row: the collapse chevron, the name
/// (double-tap renames inline), and the section menu on right-click.
final class _SectionHeader extends StatefulWidget {
  const _SectionHeader({
    required this.name,
    required this.collapsed,
    required this.onToggle,
    required this.onRenamed,
    required this.menuItems,
    super.key,
  });

  final String name;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<String> onRenamed;
  final List<OiMenuItem> menuItems;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

final class _SectionHeaderState extends State<_SectionHeader> {
  bool _renaming = false;
  int _lastTapMs = 0;

  void _tap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapMs < 350) setState(() => _renaming = true);
    _lastTapMs = now;
  }

  void _commit(String next) {
    setState(() => _renaming = false);
    final trimmed = next.trim();
    if (trimmed.isNotEmpty) widget.onRenamed(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OiContextMenu(
      label: 'Section ${widget.name} menu',
      items: widget.menuItems,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
        child: Row(
          children: [
            OiIconButton(
              icon: widget.collapsed ? OiIcons.chevronRight : OiIcons.chevronDown,
              semanticLabel: widget.collapsed ? 'Expand ${widget.name}' : 'Collapse ${widget.name}',
              onTap: widget.onToggle,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: _renaming
                  ? InspectorTextField(value: widget.name, onChanged: _commit)
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _tap,
                      child: OiLabel.small(widget.name, color: colors.textSubtle),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
