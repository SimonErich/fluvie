part of 'media_bin_panel.dart';

/// One row of the bin: what the file is, and what was probed of it.
final class MediaBinRow extends StatelessWidget {
  /// Shows [entry].
  const MediaBinRow({required this.entry, required this.selected, required this.onTap, super.key});

  /// The entry this row shows.
  final MediaStoreEntry entry;

  /// Whether this row is the selected one.
  final bool selected;

  /// Selects this row.
  final VoidCallback onTap;

  /// The probed facts worth showing, joined — empty when nothing was probed.
  ///
  /// An unprobed file says nothing rather than showing zeros, because a zero
  /// here would read as a fact.
  static String detailFor(MediaStoreEntry entry) => [
    if (entry.duration != null) entry.duration!,
    if (entry.width != null && entry.height != null) '${entry.width}x${entry.height}',
    if (entry.kind == MediaStoreKind.video && entry.fps != null)
      '${entry.fps!.toStringAsFixed(entry.fps! % 1 == 0 ? 0 : 2)}fps',
    if (entry.channels != null) '${entry.channels} audio channels',
    if (entry.folder != null) entry.folder!,
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detail = detailFor(entry);
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: selected ? colors.surfaceActive : colors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              OiLabel.small(entry.name),
              if (detail.isNotEmpty) OiLabel.small(detail, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
