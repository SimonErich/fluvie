part of 'media_bin_panel.dart';

/// One folder filter: a small pill that reads as picked or not.
///
/// Local rather than an obers_ui component because the package ships no chip,
/// and a bin needs one badly enough not to wait for upstream.
// obers_ui upstream candidate: a selectable filter pill.
final class _FolderChip extends StatelessWidget {
  const _FolderChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? colors.accent.base.withValues(alpha: 0.18) : colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: OiLabel.small(label, color: selected ? colors.accent.base : colors.textMuted),
        ),
      ),
    );
  }
}
