part of 'layers_panel.dart';

/// One panel row: the name (inline-renaming), the hide and lock toggles,
/// and — for groups — the expand chevron in front and the block-kind chip
/// after the name.
final class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.name,
    required this.selected,
    required this.locked,
    required this.hidden,
    required this.renaming,
    required this.onTap,
    required this.onRenamed,
    required this.onLock,
    required this.onHide,
    this.badge,
    this.expanded,
    this.onToggleExpand,
    super.key,
  });

  final String name;
  final bool selected;
  final bool locked;
  final bool hidden;
  final bool renaming;
  final VoidCallback onTap;
  final ValueChanged<String> onRenamed;
  final VoidCallback onLock;
  final VoidCallback onHide;

  /// The block-kind chip text, or null for a plain row.
  final String? badge;

  /// Whether the group subtree is open — null for non-group rows.
  final bool? expanded;

  /// Toggles the subtree (groups only).
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: selected ? colors.accent.base.withValues(alpha: 0.15) : const Color(0x00000000),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              if (expanded case final bool open)
                OiIconButton(
                  icon: open ? OiIcons.chevronDown : OiIcons.chevronRight,
                  semanticLabel: open ? 'Collapse $name' : 'Expand $name',
                  onTap: onToggleExpand ?? onTap,
                ),
              Expanded(
                child: renaming
                    ? InspectorTextField(value: name, onChanged: onRenamed)
                    : OiLabel.small(
                        name,
                        color: hidden ? colors.textMuted : colors.text,
                      ),
              ),
              if (badge case final String text)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: OiBadge.soft(label: text, size: OiBadgeSize.small),
                ),
              EditorTip(
                message: hidden ? 'Show $name' : 'Hide $name',
                child: OiIconButton(
                  icon: hidden ? OiIcons.eyeOff : OiIcons.eye,
                  semanticLabel: hidden ? 'Show $name' : 'Hide $name',
                  onTap: onHide,
                ),
              ),
              EditorTip(
                message: locked ? 'Unlock $name' : 'Lock $name (no canvas hits)',
                child: OiIconButton(
                  icon: locked ? OiIcons.lock : OiIcons.lockOpen,
                  semanticLabel: locked ? 'Unlock $name' : 'Lock $name',
                  onTap: onLock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
