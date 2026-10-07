part of 'export_video_dialog.dart';

final class _ExportBasicFields extends StatelessWidget {
  const _ExportBasicFields(this.owner);

  final _ExportVideoFormState owner;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OiLabel.overline('QUICK PRESETS', color: colors.textMuted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final preset in const ['Draft', 'Share', 'Master'])
              OiButton.secondary(label: preset, onTap: () => owner._quickPreset(preset)),
          ],
        ),
        const SizedBox(height: 12),
        OiLabel.small(
          'The deck renders at its own aspect; only the size scales.',
          color: colors.textMuted,
        ),
        const SizedBox(height: 16),
        OiLabel.overline('RESOLUTION', color: colors.textMuted),
        const SizedBox(height: 8),
        OiSegmentedControl<int>(
          selected: owner._options.longEdge,
          expand: true,
          segments: [
            for (final edge in exportLongEdgePresets(owner._deckLongEdge))
              OiSegment(value: edge, label: '$edge'),
          ],
          onChanged: (edge) =>
              owner._refresh(() => owner._options = owner._options.copyWith(longEdge: edge)),
        ),
        const SizedBox(height: 6),
        OiLabel.small(owner._sizeLabel(owner._options.longEdge), color: colors.textMuted),
        const SizedBox(height: 16),
        OiLabel.overline('QUALITY', color: colors.textMuted),
        const SizedBox(height: 8),
        OiSegmentedControl<Quality>(
          selected: owner._options.quality,
          expand: true,
          segments: [
            for (final quality in Quality.values) OiSegment(value: quality, label: quality.name),
          ],
          onChanged: (quality) =>
              owner._refresh(() => owner._options = owner._options.copyWith(quality: quality)),
        ),
        const SizedBox(height: 16),
        OiLabel.overline('FRAME RATE', color: colors.textMuted),
        const SizedBox(height: 8),
        OiSegmentedControl<int>(
          selected: owner._fps,
          expand: true,
          segments: [
            for (final fps in const [24, 25, 30, 60]) OiSegment(value: fps, label: '$fps'),
          ],
          onChanged: (fps) => owner._refresh(() => owner._fps = fps),
        ),
      ],
    );
  }
}
